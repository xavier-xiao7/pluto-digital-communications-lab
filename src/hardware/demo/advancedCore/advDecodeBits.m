function result=advDecodeBits(bits,cfg)
% Receive binary frames using only public protocol fields and received bits.
% No transmitted text, bytes, frame positions, or channel parameters are read.
if nargin<2,cfg=advProtocolConfig();end
assert((isvector(bits)||isempty(bits))&&all(bits(:)==0|bits(:)==1), ...
    'ADV:BinaryInput','Input must be a vector of binary 0/1 values.');
assert(cfg.headerBytes==53&&cfg.headerCodedBits==896&&cfg.maxPayload==256, ...
    'ADV:ProtocolFormat','Unsupported fixed header or payload format.');
bits=double(bits(:));sync=double(cfg.sync(:));syncLength=numel(sync);
frames=struct('startBit',{},'endBit',{},'bodyStartBit',{},'sequence',{}, ...
    'total',{},'messageId',{},'sha256Hex',{},'messageBytes',{},'payloadType',{}, ...
    'length',{},'payload',{},'crcOK',{},'syncErrors',{},'correctedErrors',{});
observed=frames;headerRejected=0;crcRejected=0;fecRejected=0;
lineCodeRejected=0;truncatedFrames=0;correctedErrors=0;detectedDoubleErrors=0;
if numel(bits)>=syncLength
    score=conv(2*bits-1,flipud(2*sync-1),'valid');
    candidates=find(score>=syncLength-2*cfg.maxSyncErrors);
else
    candidates=zeros(0,1);
end
lastAcceptedEnd=0;
for index=1:numel(candidates)
    start=candidates(index);
    if start<=lastAcceptedEnd,continue;end
    headStart=start+syncLength;headEnd=headStart+cfg.headerCodedBits-1;
    if headEnd>numel(bits),truncatedFrames=truncatedFrames+1;continue;end
    encodedHeader=advDeinterleave(bits(headStart:headEnd),16,53*16);
    [headerBits,hs]=advHammingDecode(encodedHeader);
    detectedDoubleErrors=detectedDoubleErrors+hs.detectedDoubleErrors;
    if hs.detectedDoubleErrors>0,headerRejected=headerRejected+1;continue;end
    header=advBitsToBytes(headerBits);
    if ~isequal(header(1:3),uint8([167;211;1]))|| ...
            advCrc16(header(1:51))~=readNumber(header(52:53))
        headerRejected=headerRejected+1;continue;
    end
    flags=double(header(4));payloadType=double(header(5));
    len=readNumber(header(6:7));sequence=readNumber(header(8:9));
    total=readNumber(header(10:11));messageBytes=readNumber(header(12:15));
    messageId=readNumber(header(16:19));hash=header(20:51);
    fec=bitget(uint8(flags),1)==1;manchester=bitget(uint8(flags),2)==1;
    interleave=bitget(uint8(flags),3)==1;
    if flags>7||(~fec&&interleave)||~ismember(payloadType,[1 2 3])|| ...
            messageBytes>65535*256||total~=max(1,ceil(messageBytes/256))|| ...
            sequence<1||sequence>total||len>256|| ...
            len~=max(0,min(256,messageBytes-(sequence-1)*256))|| ...
            ~isequal(header(16:19),hash(1:4))
        headerRejected=headerRejected+1;continue;
    end
    correctedErrors=correctedErrors+hs.correctedErrors;
    originalBits=(len+2)*8;codedBits=originalBits*(1+double(fec));
    interleavedBits=codedBits;
    if interleave,interleavedBits=128*ceil(codedBits/128);end
    wireBits=interleavedBits*(1+double(manchester));
    bodyStart=headEnd+1;last=bodyStart+wireBits-1;
    if last>numel(bits),truncatedFrames=truncatedFrames+1;continue;end
    body=bits(bodyStart:last);
    if manchester
        pairs=reshape(body,2,[]);
        if any(pairs(1,:)==pairs(2,:))
            lineCodeRejected=lineCodeRejected+1;continue;
        end
        body=pairs(1,:).';
    end
    if interleave,body=advDeinterleave(body,16,codedBits);end
    bs=struct('correctedErrors',0,'detectedDoubleErrors',0);
    if fec
        [body,bs]=advHammingDecode(body);
        correctedErrors=correctedErrors+bs.correctedErrors;
        detectedDoubleErrors=detectedDoubleErrors+bs.detectedDoubleErrors;
        if bs.detectedDoubleErrors>0,fecRejected=fecRejected+1;continue;end
    end
    bodyBytes=advBitsToBytes(body);payload=bodyBytes(1:len);
    valid=advCrc16([header(1:51);payload])==readNumber(bodyBytes(end-1:end));
    hashHex=lower(reshape(dec2hex(hash,2).',1,[]));
    frame=struct('startBit',start,'endBit',last,'bodyStartBit',bodyStart, ...
        'sequence',sequence,'total',total,'messageId',messageId,'sha256Hex',hashHex, ...
        'messageBytes',messageBytes,'payloadType',payloadType,'length',len, ...
        'payload',payload,'crcOK',valid,'syncErrors',sum(bits(start:start+syncLength-1)~=sync), ...
        'correctedErrors',hs.correctedErrors+bs.correctedErrors);
    observed(end+1)=frame; %#ok<AGROW>
    if valid
        frames(end+1)=frame;lastAcceptedEnd=last; %#ok<AGROW>
    else
        crcRejected=crcRejected+1;
    end
end

groups=struct('key',{},'messageId',{},'sha256Hex',{},'total',{}, ...
    'messageBytes',{},'payloadType',{},'parts',{},'present',{},'conflicts',{});
for k=1:numel(frames)
    frame=frames(k);
    key=sprintf('%s:%d:%d:%d',frame.sha256Hex,frame.payloadType,frame.total,frame.messageBytes);
    g=find(strcmp({groups.key},key),1);
    if isempty(g)
        g=numel(groups)+1;
        groups(g)=struct('key',key,'messageId',frame.messageId,'sha256Hex',frame.sha256Hex, ...
            'total',frame.total,'messageBytes',frame.messageBytes,'payloadType',frame.payloadType, ...
            'parts',{cell(frame.total,1)},'present',false(frame.total,1),'conflicts',0);
    end
    sequence=frame.sequence;
    if ~groups(g).present(sequence)
        groups(g).parts{sequence}=frame.payload;groups(g).present(sequence)=true;
    elseif ~isequal(groups(g).parts{sequence},frame.payload)
        groups(g).conflicts=groups(g).conflicts+1;
    end
end
messageGroups=struct('messageId',{},'sha256Hex',{},'total',{},'messageBytes',{}, ...
    'payloadType',{},'validSegments',{},'missingFrames',{},'conflictingCopies',{}, ...
    'messageChecksumOK',{},'complete',{},'bytes',{});
for g=1:numel(groups)
    missing=find(~groups(g).present).';candidate=zeros(0,1,'uint8');checksumOK=false;
    if isempty(missing)&&groups(g).conflicts==0
        candidate=vertcat(groups(g).parts{:});
        [~,actualHash]=advSha256(candidate);
        checksumOK=numel(candidate)==groups(g).messageBytes&&strcmp(actualHash,groups(g).sha256Hex);
    end
    complete=isempty(missing)&&groups(g).conflicts==0&&checksumOK;
    if ~complete,candidate=zeros(0,1,'uint8');end
    messageGroups(g)=struct('messageId',groups(g).messageId,'sha256Hex',groups(g).sha256Hex, ...
        'total',groups(g).total,'messageBytes',groups(g).messageBytes,'payloadType',groups(g).payloadType, ...
        'validSegments',sum(groups(g).present),'missingFrames',missing, ...
        'conflictingCopies',groups(g).conflicts,'messageChecksumOK',checksumOK, ...
        'complete',complete,'bytes',candidate);
end
bytes=zeros(0,1,'uint8');complete=false;missing=[];messageId=[];payloadType=[];hashHex='';
if ~isempty(messageGroups)
    chosen=find([messageGroups.complete],1);if isempty(chosen),chosen=1;end
    complete=messageGroups(chosen).complete;bytes=messageGroups(chosen).bytes;
    missing=messageGroups(chosen).missingFrames;messageId=messageGroups(chosen).messageId;
    payloadType=messageGroups(chosen).payloadType;hashHex=messageGroups(chosen).sha256Hex;
end
result=struct('bytes',bytes,'complete',complete,'payloadType',payloadType, ...
    'sha256Hex',hashHex,'messageId',messageId,'frames',frames,'observedFrames',observed, ...
    'messageGroups',messageGroups,'validFrameCount',numel(frames),'syncCandidates',numel(candidates), ...
    'missingFrames',missing,'conflictingCopies',sum([messageGroups.conflictingCopies]), ...
    'correctedErrors',correctedErrors,'detectedDoubleErrors',detectedDoubleErrors, ...
    'headerRejected',headerRejected,'crcRejected',crcRejected,'fecRejected',fecRejected, ...
    'lineCodeRejected',lineCodeRejected,'truncatedFrames',truncatedFrames);
end

function value=readNumber(bytes)
value=0;for byte=double(bytes(:)).',value=256*value+byte;end
end

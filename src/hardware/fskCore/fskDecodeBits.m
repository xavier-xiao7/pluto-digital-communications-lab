function result=fskDecodeBits(bits,cfg)
% Sync, length, sequence and CRC parsing using public protocol fields only.
assert(isvector(bits)&&all(bits(:)==0|bits(:)==1),'FSK:BinaryInput', ...
    'Input must contain only 0/1 bits.');
bits=logical(bits(:));sync=logical(cfg.sync(:));L=numel(sync);
assert(cfg.headerBytes==6,'FSK:HeaderFormat','This protocol requires a six-byte header.');
H=8*cfg.headerBytes;
empty=struct('startBit',{},'endBit',{},'payloadStartBit',{},'sequence',{}, ...
    'total',{},'messageId',{},'length',{},'text',{},'crcOK',{},'syncErrors',{},'payloadBits',{});
frames=empty;observations=empty;candidates=0;badCRC=0;k=1;
while k<=numel(bits)-L-H-24+1
    errors=sum(bits(k:k+L-1)~=sync);
    if errors>cfg.frameHeaderErrors,k=k+1;continue;end
    candidates=candidates+1;p=k+L;h=fskBitsToBytes(bits(p:p+H-1));
    len=double(h(1))*256+double(h(2));seq=double(h(3));total=double(h(4));
    messageId=bitor(bitshift(uint16(h(5)),8),uint16(h(6)));
    last=p+H+8*len+16-1;
    if len<1||len>cfg.maxPayload||seq<1||seq>total||last>numel(bits)
        k=k+1;continue;
    end
    bytes=fskBitsToBytes(bits(p:last));
    observed=bitor(bitshift(uint16(bytes(end-1)),8),uint16(bytes(end)));
    valid=fskCrc16(bytes(1:end-2))==observed;
    frame=struct('startBit',k,'endBit',last,'payloadStartBit',p+H, ...
        'sequence',seq,'total',total,'messageId',messageId,'length',len, ...
        'text',char(bytes(cfg.headerBytes+1:end-2).'),'crcOK',valid,'syncErrors',errors, ...
        'payloadBits',bits(p+H:last-16));
    observations(end+1)=frame; %#ok<AGROW>
    if valid
        frames(end+1)=frame;k=last+1; %#ok<AGROW>
    else
        badCRC=badCRC+1;k=k+1;
    end
end
% Whole-message CRC is a compact grouping key and a final error check.
% It is not a cryptographically unique ID; ordinary CRC collisions remain.
groups=struct('messageId',{},'total',{},'parts',{},'conflicts',{});
for j=1:numel(frames)
    g=find([groups.messageId]==frames(j).messageId & [groups.total]==frames(j).total,1);
    if isempty(g)
        g=numel(groups)+1;
        groups(g)=struct('messageId',frames(j).messageId,'total',frames(j).total, ...
            'parts',{cell(1,frames(j).total)},'conflicts',0);
    end
    seq=frames(j).sequence;
    if isempty(groups(g).parts{seq})
        groups(g).parts{seq}=frames(j).text;
    elseif ~strcmp(groups(g).parts{seq},frames(j).text)
        groups(g).conflicts=groups(g).conflicts+1;
    end
end
messageGroups=struct('messageId',{},'total',{},'validSegments',{},'missingFrames',{}, ...
    'conflictingCopies',{},'messageChecksumOK',{},'complete',{},'message',{});
for g=1:numel(groups)
    missing=find(cellfun(@isempty,groups(g).parts));candidate='';checksumOK=false;
    if isempty(missing)&&groups(g).conflicts==0
        candidate=[groups(g).parts{:}];checksumOK=fskCrc16(uint8(candidate))==groups(g).messageId;
    end
    good=isempty(missing)&&groups(g).conflicts==0&&checksumOK;
    if ~good,candidate='';end
    messageGroups(g)=struct('messageId',groups(g).messageId,'total',groups(g).total, ...
        'validSegments',groups(g).total-numel(missing),'missingFrames',missing, ...
        'conflictingCopies',groups(g).conflicts,'messageChecksumOK',checksumOK, ...
        'complete',good,'message',candidate);
end
message='';complete=false;missing=[];messageId=[];conflicts=0;
allMessages={messageGroups([messageGroups.complete]).message};
if ~isempty(messageGroups)
    chosen=find([messageGroups.complete],1);
    if isempty(chosen),chosen=1;end
    complete=messageGroups(chosen).complete;message=messageGroups(chosen).message;
    missing=messageGroups(chosen).missingFrames;messageId=messageGroups(chosen).messageId;
    conflicts=sum([messageGroups.conflictingCopies]);
end
result=struct('frames',frames,'observedFrames',observations, ...
    'validFrameCount',numel(frames),'syncCandidates',candidates, ...
    'crcRejected',badCRC,'conflictingCopies',conflicts,'message',message, ...
    'complete',complete,'missingFrames',missing,'messageId',messageId, ...
    'messageGroups',messageGroups,'allMessages',{allMessages});
end

function [bits,truth]=advEncodeBytes(bytes,cfg)
% Generic binary packet encoder. truth is evaluator-only; never feed to RX.
if nargin<2,cfg=advProtocolConfig();end
assert(isa(bytes,'uint8')&&(isvector(bytes)||isempty(bytes)), ...
    'ADV:ByteType','Supply a uint8 byte vector.');
bytes=bytes(:);
assert(numel(bytes)<=65535*256,'ADV:MessageTooLong', ...
    'A message can contain at most 65535 fixed-size 256-byte fragments.');
assert(cfg.maxPayload==256&&cfg.headerBytes==53&&cfg.headerCodedBits==896, ...
    'ADV:ProtocolFormat','This version uses fixed 256-byte payloads and 53-byte headers.');
assert(cfg.headerInterleaveDepth==16&&cfg.interleaveDepth==16, ...
    'ADV:ProtocolFormat','This version uses an interleave depth of 16.');
validateattributes(cfg.repetitions,{'numeric'},{'scalar','integer','positive'});
validateattributes(cfg.payloadType,{'numeric'},{'scalar','integer','>=',1,'<=',3});
assert(isscalar(cfg.fec)&&isscalar(cfg.interleave),'ADV:ProtocolFlag','Use scalar flags.');
lineCode=char(cfg.lineCode);
assert(any(strcmpi(lineCode,{'NRZ','Manchester'})),'ADV:LineCode','Use NRZ or Manchester.');
manchester=strcmpi(lineCode,'Manchester');fec=logical(cfg.fec);
interleave=logical(cfg.interleave)&&fec;
flags=uint8(fec+2*manchester+4*interleave);
[hash,hashHex]=advSha256(bytes);messageId=readNumber(hash(1:4));
count=max(1,ceil(numel(bytes)/256));frames=cell(count,1);headers=cell(count,1);
bodyOffsets=zeros(count,1);frameStarts=zeros(count,1);offset=1;
for sequence=1:count
    first=(sequence-1)*256+1;last=min(sequence*256,numel(bytes));
    payload=bytes(first:last);
    header=[uint8([167;211;1]);flags;uint8(cfg.payloadType); ...
        putNumber(numel(payload),2);putNumber(sequence,2);putNumber(count,2); ...
        putNumber(numel(bytes),4);hash(1:4);hash];
    crc=advCrc16(header);header=[header;putNumber(crc,2)];
    protectedHeader=advInterleave(advHammingEncode(advBytesToBits(header)),16);
    frameCrc=advCrc16([header(1:51);payload]);
    body=advBytesToBits([payload;putNumber(frameCrc,2)]);
    if fec,body=advHammingEncode(body);end
    if interleave,body=advInterleave(body,16);end
    if manchester,pairs=[body.';1-body.'];body=pairs(:);end
    bodyOffsets(sequence)=numel(cfg.preamble)+numel(cfg.sync)+numel(protectedHeader);
    frames{sequence}=[cfg.preamble(:);cfg.sync(:);protectedHeader;body;zeros(cfg.guardBits,1)];
    headers{sequence}=header;frameStarts(sequence)=offset;offset=offset+numel(frames{sequence});
end
copyLength=offset-1;allFrames=repmat(frames,cfg.repetitions,1);bits=vertcat(allFrames{:});
starts=reshape(frameStarts+(0:cfg.repetitions-1)*copyLength,[],1);
bodyStarts=starts+repmat(bodyOffsets,cfg.repetitions,1);
truth=struct('bits',bits,'frames',{allFrames},'headers',{repmat(headers,cfg.repetitions,1)}, ...
    'frameCount',count,'expectedCopies',count*cfg.repetitions, ...
    'frameBitStarts',starts,'bodyBitStarts',bodyStarts,'messageId',messageId, ...
    'sha256Hex',hashHex,'byteCount',numel(bytes),'payloadType',cfg.payloadType);
end

function bytes=putNumber(value,count)
value=double(value);bytes=zeros(count,1,'uint8');
for k=count:-1:1,bytes(k)=uint8(mod(value,256));value=floor(value/256);end
end

function value=readNumber(bytes)
value=0;for byte=double(bytes(:)).',value=256*value+byte;end
end

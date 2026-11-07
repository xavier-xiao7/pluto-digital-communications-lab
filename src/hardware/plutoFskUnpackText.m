function [message,transport]=plutoFskUnpackText(wire)
% Call only after all existing frame and whole-message CRC checks pass.
prefix='~PLUTO-UTF8-1~';
assert(ischar(wire)&&isrow(wire)&&~isempty(wire),'PLUTO:WireText','Invalid wire text.');
if ~startsWith(wire,prefix)
    message=wire;transport=struct('encoding','ASCII','utf8Bytes',numel(wire),'wireAsciiBytes',numel(wire),'checksumDomain','wire-ascii');return
end
hex=wire(numel(prefix)+1:end);
assert(~isempty(hex)&&mod(numel(hex),2)==0&&all(ismember(hex,'0123456789ABCDEF')), ...
    'PLUTO:Utf8Envelope','Malformed UTF-8 envelope.');
bytes=uint8(hex2dec(reshape(hex,2,[]).')).';
message=native2unicode(bytes,'UTF-8');
assert(isequal(unicode2native(message,'UTF-8'),bytes),'PLUTO:Utf8Bytes','Invalid UTF-8 bytes.');
transport=struct('encoding','UTF-8/hex-v1','utf8Bytes',numel(bytes),'wireAsciiBytes',numel(wire),'checksumDomain','wire-ascii');
end

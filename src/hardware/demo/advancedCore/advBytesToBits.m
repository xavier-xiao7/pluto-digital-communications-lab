function bits=advBytesToBits(bytes)
% Byte values to a double column, MSB first in each byte.
assert(isa(bytes,'uint8'),'ADV:ByteType','Supply uint8 bytes.');
bytes=bytes(:);bits=zeros(8*numel(bytes),1);
for k=1:8,bits(k:8:end)=double(bitget(bytes,9-k));end
end

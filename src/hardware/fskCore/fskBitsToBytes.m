function bytes=fskBitsToBytes(bits)
% Inverse of the documented eight-bit MSB-first on-air representation.
assert(isvector(bits)&&mod(numel(bits),8)==0,'FSK:ByteLength', ...
    'Byte input must contain a multiple of eight bits.');
assert(all(bits(:)==0|bits(:)==1),'FSK:BinaryInput','Input must contain only 0/1 bits.');
bytes=uint8(reshape(double(bits),8,[]).'*2.^(7:-1:0).');
end

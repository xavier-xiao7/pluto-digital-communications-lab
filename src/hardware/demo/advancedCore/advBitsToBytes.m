function bytes=advBitsToBytes(bits)
assert(all(bits(:)==0|bits(:)==1)&&mod(numel(bits),8)==0, ...
    'ADV:ByteBits','Use a multiple of eight binary bits.');
matrix=reshape(double(bits(:)),8,[]);
bytes=uint8((2.^(7:-1:0))*matrix).';
end

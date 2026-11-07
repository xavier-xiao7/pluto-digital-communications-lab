function crc=advCrc16(bytes)
% CRC-16/CCITT-FALSE, poly 1021, init FFFF, no reflection, xorout 0.
% Independent standard check: ASCII '123456789' -> 0x29B1.
persistent lut
if isempty(lut)
    lut=zeros(256,1,'uint16');
    for n=0:255
        value=bitshift(uint16(n),8);
        for k=1:8
            high=bitget(value,16);value=bitshift(value,1);
            if high,value=bitxor(value,uint16(4129));end
        end
        lut(n+1)=value;
    end
end
crc=uint16(65535);
for byte=uint8(bytes(:)).'
    index=bitxor(bitshift(crc,-8),uint16(byte));
    crc=bitxor(bitshift(crc,8),lut(double(index)+1));
end
end

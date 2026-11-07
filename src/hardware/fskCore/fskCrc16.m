function crc=fskCrc16(bytes)
% CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection, xorout 0.
% Standard check: ASCII '123456789' -> hexadecimal 29B1.
crc=uint16(65535);
for b=uint8(bytes(:)).'
    crc=bitxor(crc,bitshift(uint16(b),8));
    for k=1:8
        high=bitget(crc,16);crc=bitshift(crc,1);
        if high,crc=bitxor(crc,uint16(hex2dec('1021')));end
    end
end
end

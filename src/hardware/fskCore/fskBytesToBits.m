function bits=fskBytesToBits(bytes)
% Eight-bit, most-significant-bit-first byte serialization.
validateattributes(bytes,{'numeric','logical'},{'vector','integer','>=',0,'<=',255});
bits=reshape((dec2bin(uint8(bytes(:)),8)-'0').',[],1);
end

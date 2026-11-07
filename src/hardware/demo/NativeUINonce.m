function nonce=NativeUINonce()
% Six independently generated random bytes; never reuse as a network runId.
generator=java.security.SecureRandom();bytes=generator.generateSeed(6);
nonce=lower(reshape(dec2hex(typecast(int8(bytes(:)),'uint8'),2).',1,[]));
end

function [digest,hex]=advSha256(bytes)
% SHA-256 of bytes only, using MATLAB's bundled Java security implementation.
assert(isa(bytes,'uint8'),'ADV:ByteType','Supply uint8 bytes.');
engine=java.security.MessageDigest.getInstance('SHA-256');
if ~isempty(bytes),engine.update(typecast(bytes(:),'int8'));end
digest=typecast(engine.digest(),'uint8');digest=digest(:);
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end

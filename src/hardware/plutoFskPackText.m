function [wire,transport]=plutoFskPackText(message)
% Preserve the teacher ASCII protocol; carry UTF-8 bytes in a versioned envelope.
assert(ischar(message)||(isstring(message)&&isscalar(message)),'PLUTO:TextType','Use one text value.');
message=char(message);assert(isrow(message)&&~isempty(message),'PLUTO:TextShape','Use nonempty row text.');
prefix='~PLUTO-UTF8-1~';bytes=unicode2native(message,'UTF-8');
assert(strcmp(native2unicode(bytes,'UTF-8'),message),'PLUTO:UnicodeText','Text must round-trip through UTF-8.');
if all(double(message)<=127)&&~startsWith(message,prefix)
    wire=message;encoding='ASCII';
else
    wire=[prefix reshape(dec2hex(bytes,2).',1,[])];encoding='UTF-8/hex-v1';
end
transport=struct('encoding',encoding,'utf8Bytes',numel(bytes),'wireAsciiBytes',numel(wire),'checksumDomain','wire-ascii');
end

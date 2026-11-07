function [packet,meta,data]=demoEnvelope(action,varargin)
% Self-contained on-air metadata. The receiver has no expected TX content.
demoInit();magic=uint8('PLUTODEMO2').';
if strcmp(action,'pack')
    data=uint8(varargin{1}(:));kind=char(varargin{2});name=char(varargin{3});
    assert(numel(data)<=1024,'DEMO:Size','本版载荷最多1024字节。');
    [~,hash]=advSha256(data);
    meta=struct('nonce',NativeUINonce(),'kind',kind,'name',name,'bytes',numel(data),'sha256',hash);
    header=unicode2native(jsonencode(meta),'UTF-8').';L=numel(header);
    assert(L<2048,'DEMO:Header','Header is too long.');
    packet=[magic;uint8(floor(L/256));uint8(mod(L,256));header;data];
else
    packet=uint8(varargin{1}(:));
    assert(numel(packet)>=12&&isequal(packet(1:10),magic),'DEMO:Envelope','无线封装标识不匹配。');
    L=double(packet(11))*256+double(packet(12));
    assert(L>0&&L<=2048&&numel(packet)>=12+L,'DEMO:Header','无线封装长度无效。');
    meta=jsondecode(native2unicode(packet(13:12+L).','UTF-8'));data=packet(13+L:end);
    assert(all(isfield(meta,{'nonce','kind','name','bytes','sha256'})),'DEMO:Header','无线元数据不完整。');
    assert(~isempty(regexp(meta.nonce,'^[a-f0-9]{12}$','once')),'DEMO:Nonce','无线标记无效。');
    assert(ismember(meta.kind,{'text','file'})&&ischar(meta.name),'DEMO:Kind','未知载荷类型。');
    [~,hash]=advSha256(data);
    assert(numel(data)==meta.bytes&&numel(data)<=1024&&strcmp(hash,meta.sha256),'DEMO:Hash','载荷摘要或长度不一致。');
end
end

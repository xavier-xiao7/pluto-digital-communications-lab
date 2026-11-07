function [audio,info]=advSoundcardTransmit(bytes,cfg,path)
% Encode arbitrary bytes as a real audio carrier. WAV-only by default.
% This function never calls sound/audioplayer or opens an audio device.
if nargin<2||isempty(cfg),cfg=advSoundcardConfig();end
if nargin<3,path='';end
[bits,protocolInfo]=advEncodeBytes(bytes,cfg.protocol);
[audio,info]=advSoundcardModulate(bits,cfg);
info.protocol=protocolInfo;info.wavPath=char(path);
if ~isempty(path),audiowrite(path,audio,cfg.fs,'BitsPerSample',16);end
end

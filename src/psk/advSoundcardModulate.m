function [audio,info]=advSoundcardModulate(bits,cfg)
% Map public framed bits onto orthogonal real 2FSK tones at audio rate.
% The leading/trailing silence is convenience, not receiver timing truth.
if nargin<2,cfg=advSoundcardConfig();end
validateattributes(bits,{'numeric','logical'},{'vector','nonempty','real','finite'});
assert(all(bits(:)==0|bits(:)==1),'ADV:SoundcardBits','Expected binary bits.');
validateattributes(cfg.fs,{'numeric'},{'scalar','integer','positive'});
validateattributes(cfg.sps,{'numeric'},{'scalar','integer','>=',8});
assert(cfg.sps==cfg.fs/cfg.baud,'ADV:SoundcardRates','Inconsistent sample and symbol rates.');
assert(cfg.f0>0&&cfg.f1>cfg.f0&&cfg.f1<cfg.fs/2,'ADV:SoundcardTones','Audio tones violate Nyquist.');
assert(abs((cfg.f1-cfg.f0)/cfg.baud-round((cfg.f1-cfg.f0)/cfg.baud))<1e-12, ...
    'ADV:SoundcardOrthogonality','Tone difference must span integer cycles per symbol.');
validateattributes(cfg.amplitude,{'numeric'},{'scalar','>',0,'<=',0.85});
validateattributes(cfg.leadSamples,{'numeric'},{'scalar','integer','nonnegative'});
validateattributes(cfg.tailSamples,{'numeric'},{'scalar','integer','nonnegative'});
freq=cfg.f0+(cfg.f1-cfg.f0)*repelem(double(bits(:)),cfg.sps);
% Accumulated phase preserves continuity, including noninteger tone cycles.
phase=2*pi*[0;cumsum(freq(1:end-1))]/cfg.fs;
signal=cfg.amplitude*cos(phase);
audio=[zeros(cfg.leadSamples,1);signal;zeros(cfg.tailSamples,1)];
info=struct('fs',cfg.fs,'baud',cfg.baud,'sps',cfg.sps,'bitCount',numel(bits), ...
    'durationSeconds',numel(audio)/cfg.fs,'toneHz',[cfg.f0 cfg.f1], ...
    'audioDeviceUsed',false,'physicalLinkTested',false);
end

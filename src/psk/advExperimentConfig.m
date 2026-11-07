function cfg=advExperimentConfig(options)
% Experiment/transmitter configuration. The receiver gets a separate public cfg.
if nargin<1,options=struct();end
mode='BPSK';if isfield(options,'modulation'),mode=options.modulation;end
cfg=advPskConfig(mode);cfg.protocol=advProtocolConfig();
% Robust experiment profile repeats the whole frame group twice for time diversity.
% Protocol core stays at one copy; explicit options can select a single pass.
cfg.protocol.repetitions=2;
cfg.fs=cfg.Fs;cfg.frameSamples=2000;cfg.symbolScale=cfg.symbolNormalization;
cfg.ebNo=25;cfg.channelMode='combined';cfg.awgnSeed=67;cfg.fadingSeed=73;
cfg.leadSamples=73;cfg.frequencyOffsetHz=0;cfg.phaseOffsetRad=0;
cfg.pulseShape='rrc';
names=fieldnames(options);
for k=1:numel(names)
 name=names{k};
 if strcmp(name,'protocol')
  fields=fieldnames(options.protocol);for j=1:numel(fields),cfg.protocol.(fields{j})=options.protocol.(fields{j});end
 else,cfg.(name)=options.(name);end
end
assert(cfg.fs==cfg.Fs&&cfg.Fs/cfg.symbolRate==cfg.sps,'Sampling rates are inconsistent.');
assert(cfg.Fs==48000&&cfg.sps==16,'This validated version uses Fs=48000 and sps=16.');
assert(ismember(cfg.channelMode,{'ideal','awgn','rician','combined'}));
assert(abs(cfg.fc+cfg.frequencyOffsetHz)+(1+cfg.rolloff)*cfg.symbolRate/2<cfg.fs/2,'Carrier band crosses Nyquist.');
if strcmp(cfg.pulseShape,'rrc')
 h=rcosdesign(cfg.rolloff,cfg.filterSpan,cfg.sps,'sqrt');
elseif strcmp(cfg.pulseShape,'rectangular')
 h=ones(1,cfg.sps)/sqrt(cfg.sps);
else,error('Unknown pulseShape.');end
cfg.txFilter=sqrt(cfg.sps)*h;cfg.rxFilter=h/sqrt(cfg.sps);
end

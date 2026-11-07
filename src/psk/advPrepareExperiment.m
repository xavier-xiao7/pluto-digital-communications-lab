function [txWave,txQWave,txGate,truth]=advPrepareExperiment(payload,cfg)
% Source encoding, serialization, public training insertion, and sample timing.
% +/-1 mapping, actual carrier modulation and pulse filtering are in Simulink.
if ischar(payload)||isstring(payload),payload=uint8(unicode2native(char(payload),'UTF-8')).';end
assert(isa(payload,'uint8')&&isvector(payload)||isempty(payload),'Use text or a uint8 byte vector.');
[~,truth]=advEncodeBytes(payload(:),cfg.protocol);
[ib,qb,active,phy]=advPskFrameBits(truth.frames,advPskConfig(cfg.modulation));
txWave=repelem(double(ib),cfg.sps);txQWave=repelem(double(qb),cfg.sps);
txGate=zeros(numel(txWave),1);txGate(1:cfg.sps:end)=active;
tail=2*cfg.filterSpan*cfg.sps;
txWave=[zeros(cfg.leadSamples,1);txWave;zeros(tail,1)];
txQWave=[zeros(cfg.leadSamples,1);txQWave;zeros(tail,1)];
txGate=[zeros(cfg.leadSamples,1);txGate;zeros(tail,1)];
padding=mod(-numel(txWave),cfg.frameSamples);
txWave=[txWave;zeros(padding,1)];txQWave=[txQWave;zeros(padding,1)];txGate=[txGate;zeros(padding,1)];
truth.phy=phy;truth.sourceBytes=payload(:);truth.sampleCount=numel(txWave);
end

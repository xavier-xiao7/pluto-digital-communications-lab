function result=fskDecodeWave(rxWave,cfg)
% Signed FSK energy metric -> second-order clock PLL -> decisions -> protocol.
% Input z=(E1-E0)/(E1+E0+epsilon) comes from the Simulink demodulator.
% Does not read TX samples, bits, text, channel delay or injected clock drift.
% 'fixed' uses a free-running nominal clock for the synchronization comparison.
validateattributes(cfg.sps,{'numeric'},{'scalar','integer','>=',4});
assert(cfg.sps==cfg.fs/cfg.baud,'FSK:RateMismatch','Inconsistent receiver rates.');
if isa(rxWave,'timeseries'),rxWave=rxWave.Data;end
z=double(rxWave(:));
assert(~isempty(z)&&isreal(z)&&all(isfinite(z)),'FSK:SoftInput', ...
    'The receiver requires a finite, real signed energy metric.');
mode=validatestring(cfg.timingMode,{'pll','fixed'});
assert(cfg.pllAlpha>=0&&cfg.pllAlpha<1&&cfg.pllBeta>=0,'FSK:LoopGain','Invalid PLL gains.');
nominalStep=1/cfg.sps;step=nominalStep;
loStep=nominalStep/(1+cfg.maxClockPpm*1e-6);
hiStep=nominalStep/(1-cfg.maxClockPpm*1e-6);
assert(cfg.maxClockPpm>=0&&cfg.maxClockPpm<1e6,'FSK:ClockRange','Invalid clock capture range.');
phase=0;
if strcmp(mode,'fixed'),phase=0.5-cfg.fixedPhaseSamples/cfg.sps;end
state=z(1)>0;lastEdge=-Inf;n=0;edgeCount=0;
capacity=ceil(numel(z)*hiStep)+100;
idx=zeros(capacity,1);period=zeros(capacity,1);
edges=zeros(capacity,1);edgeError=zeros(capacity,1);
phaseTrace=zeros(numel(z),1);
for k=1:numel(z)
    next=state;
    if z(k)>cfg.timingHysteresis,next=true;
    elseif z(k)<-cfg.timingHysteresis,next=false;end
    if next~=state && k-lastEdge>=cfg.minEdgeSpacing*cfg.sps
        state=next;lastEdge=k;edgeCount=edgeCount+1;
        edges(edgeCount)=k;edgeError(edgeCount)=phase;
        if strcmp(mode,'pll')
            if edgeCount==1
                phase=0;
            else
                % The edge is expected at phase 0. Negative phase -> speed up.
                step=min(hiStep,max(loStep,step-cfg.pllBeta*phase/cfg.sps));
                phase=cfg.pllAlpha*phase;
            end
        end
    end
    phase=phase+step;
    if phase>=0.5
        phase=phase-1;n=n+1;idx(n)=k;period(n)=1/step;
    end
    phaseTrace(k)=phase;
end
idx=idx(1:n);bits=z(idx)>0;
result=fskDecodeBits(bits,cfg);
result.sampleIndices=idx;result.bits=bits;result.normalizedWave=z;
result.phase=phaseTrace;result.threshold=zeros(size(z));
result.timingMode=mode;
result.timingAlgorithm='second-order transition-driven hysteresis PLL';
if strcmp(mode,'fixed'),result.timingAlgorithm='free-running nominal clock';end
result.timingPeriodSamples=period(1:n);
result.transitionIndices=edges(1:edgeCount);
result.transitionPhaseErrors=edgeError(1:edgeCount);
end

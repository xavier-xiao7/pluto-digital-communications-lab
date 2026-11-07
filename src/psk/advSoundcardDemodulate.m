function result=advSoundcardDemodulate(audio,cfg)
% Blind noncoherent real-FSK demodulator and transition-driven clock PLL.
% Input is only recorded samples and public modem settings. No TX truth.
if nargin<2,cfg=advSoundcardConfig();end
validateattributes(audio,{'numeric'},{'2d','nonempty','real','finite'});
if isvector(audio),audio=audio(:);end
assert(size(audio,2)<=8,'ADV:SoundcardChannels','Expected samples-by-channels audio.');
assert(cfg.sps==cfg.fs/cfg.baud&&cfg.sps>=8,'ADV:SoundcardRates','Inconsistent receiver rates.');
validateattributes(cfg.pllAlpha,{'numeric'},{'scalar','>=',0,'<',1});
validateattributes(cfg.pllBeta,{'numeric'},{'scalar','nonnegative'});
validateattributes(cfg.maxClockPpm,{'numeric'},{'scalar','>=',0,'<',1e6});
x=double(audio);x=x-mean(x,1);
n=(0:size(x,1)-1)';h=ones(cfg.sps,1)/cfg.sps;
% Each mixer is complex: an arbitrary line polarity or carrier phase is safe.
e0=abs(filter(h,1,x.*exp(-1j*2*pi*cfg.f0*n/cfg.fs))).^2;
e1=abs(filter(h,1,x.*exp(-1j*2*pi*cfg.f1*n/cfg.fs))).^2;
[~,selectedChannel]=max(mean(e0+e1,1));
e0=e0(:,selectedChannel);e1=e1(:,selectedChannel);
power=e0+e1;
z=(e1-e0)./max(power,max(power)*1e-9+realmin);
% Suppress silence transitions; energy gate depends only on received audio.
active=power>max(power)*1e-6;
z(~active)=0;
nominal=1/cfg.sps;step=nominal;phase=0;
lo=nominal/(1+cfg.maxClockPpm*1e-6);
hi=nominal/(1-cfg.maxClockPpm*1e-6);
capacity=ceil(numel(z)*hi)+100;
sampleIndices=zeros(capacity,1);period=zeros(capacity,1);
edgeIndices=zeros(capacity,1);edgeErrors=zeros(capacity,1);
state=z(1)>0;lastEdge=-Inf;edgeCount=0;count=0;
for k=1:numel(z)
    next=state;
    if z(k)>cfg.timingHysteresis,next=true;
    elseif z(k)<-cfg.timingHysteresis,next=false;end
    if active(k)&&next~=state&&k-lastEdge>=cfg.minEdgeSpacing*cfg.sps
        state=next;lastEdge=k;edgeCount=edgeCount+1;
        edgeIndices(edgeCount)=k;edgeErrors(edgeCount)=phase;
        if edgeCount==1,phase=0;
        else
            step=min(hi,max(lo,step-cfg.pllBeta*phase/cfg.sps));
            phase=cfg.pllAlpha*phase;
        end
    end
    phase=phase+step;
    if phase>=0.5
        phase=phase-1;count=count+1;
        sampleIndices(count)=k;period(count)=1/step;
    end
end
sampleIndices=sampleIndices(1:count);
result=struct('bits',z(sampleIndices)>0,'sampleIndices',sampleIndices, ...
    'normalizedWave',z,'tonePower',power,'selectedChannel',selectedChannel, ...
    'timingPeriodSamples',period(1:count),'transitionIndices',edgeIndices(1:edgeCount), ...
    'transitionPhaseErrors',edgeErrors(1:edgeCount),'fs',cfg.fs, ...
    'timingAlgorithm','receive-driven second-order transition PLL', ...
    'audioDeviceUsed',false,'physicalLinkTested',false);
end

function result = advReceivePsk(rxMatched,cfg)
%ADVRECEIVEPSK Blind acquisition + data-aided clock/carrier + DD carrier PLL.
% Inputs are matched-filter complex samples and PUBLIC PHY parameters only.
% No actual start, payload, phase, frequency, or transmitted bits are read.
% Mth-power frequency acquisition removes the data modulation. The known PN
% pilots then resolve BPSK/QPSK phase ambiguity and select symbol timing.
% A deep time-varying fade can still cause pilot loss or a PSK cycle slip.
% FEC/CRC reject damaged packets; the experiment's bounded whole-message
% repetitions provide complementary valid fragments at different times.
% This receiver does not repair such fades using transmitted payload truth.
x=double(rxMatched(:));
assert(all(isfinite(x)),'PSK:Samples','Receive samples must be finite.');
result=struct('bits',zeros(0,1),'complete',false,'bytes',uint8([]), ...
    'validFrameCount',0,'syncCandidates',0,'correctedErrors',0, ...
    'headerRejected',0,'crcRejected',0,'fecRejected',0, ...
    'lineCodeRejected',0,'truncatedFrames',0,'detectedDoubleErrors',0, ...
    'tiles',struct([]),'coarseCfoHz',NaN,'estimatedSps',cfg.sps, ...
    'estimatedClockPpm',0,'correctedSymbols',complex(zeros(0,1)), ...
    'synchronization','Mth-power CFO; public PN polyphase timing; per-tile carrier fit and second-order decision-directed PLL');
% Failed acquisition is an ordinary receive result. Preserve the same
% protocol schema on silence, short captures and no-pilot/noise captures.
hasProtocol=exist('advDecodeBits','file')==2 && exist('advProtocolConfig','file')==2;
if hasProtocol
    emptyProtocol=advDecodeBits(zeros(0,1),advProtocolConfig());
    names=fieldnames(emptyProtocol);
    for k=1:numel(names),result.(names{k})=emptyProtocol.(names{k});end
end
minimum=(cfg.trainingLength+cfg.dataSymbolsPerTile)*cfg.sps;
if numel(x)<minimum || ~any(abs(x)>1e-12), return; end
coarse=coarseFrequency(x,cfg); result.coarseCfoHz=coarse;
x=x.*exp(-1i*2*pi*coarse*(0:numel(x)-1).'/cfg.Fs);
[starts,scores]=acquireTiles(x,cfg);
if isempty(starts), return; end
tileLength=cfg.trainingLength+cfg.dataSymbolsPerTile;
% Repeated public pilots provide an observed clock period. Guard gaps are
% excluded, and this estimate contains no transmitter sample clock truth.
spacing=diff(starts); nominal=tileLength*cfg.sps;
good=abs(spacing/nominal-1)<cfg.maxClockPpm*1e-6;
if any(good)
    actualSps=median(spacing(good))/tileLength;
else
    actualSps=cfg.sps;
end
result.estimatedSps=actualSps;
result.estimatedClockPpm=(cfg.sps/actualSps-1)*1e6;
dataCells=cell(numel(starts),1); symbolCells=cell(numel(starts),1);
tiles=struct([]); accepted=0;
for k=1:numel(starts)
    [start,phase,slope,amplitude,quality,trainingEvm]= ...
        refineTraining(x,starts(k),actualSps,cfg);
    positions=start+(cfg.trainingLength+(0:cfg.dataSymbolsPerTile-1)).'*actualSps;
    if quality<cfg.correlationThreshold || positions(end)>numel(x), continue; end
    samples=sampleUniform(x,positions);
    n=cfg.trainingLength+(0:cfg.dataSymbolsPerTile-1).';
    data=samples.*exp(-1i*(phase+slope*n))/max(amplitude,eps);
    [corrected,bits,phaseErrors]=trackCarrier(data,cfg);
    accepted=accepted+1; dataCells{accepted}=bits; symbolCells{accepted}=corrected;
    tiles(accepted).sampleIndex=start; %#ok<AGROW>
    tiles(accepted).coarseCorrelation=scores(k);
    tiles(accepted).correlation=quality;
    tiles(accepted).fineCfoHz=coarse+slope*cfg.Fs/(2*pi*actualSps);
    tiles(accepted).phaseRadians=phase;
    tiles(accepted).amplitude=amplitude;
    tiles(accepted).trainingEvm=trainingEvm;
    tiles(accepted).pllPhaseErrorRms=sqrt(mean(phaseErrors.^2));
end
if accepted==0, return; end
result.bits=vertcat(dataCells{1:accepted}); result.tiles=tiles;
result.correctedSymbols=vertcat(symbolCells{1:accepted});
if hasProtocol
    decoded=advDecodeBits(result.bits,advProtocolConfig());
    names=fieldnames(decoded);
    for k=1:numel(names)
        if ~strcmp(names{k},'bits'), result.(names{k})=decoded.(names{k}); end
    end
end
end

function cfo=coarseFrequency(x,cfg)
% Acquire from the first finite observation window; pick the strongest of
% the oversampling phases, rather than assuming a symbol sampling phase.
count=min(floor(numel(x)/cfg.sps),16384);
energy=zeros(cfg.sps,1);
for p=1:cfg.sps, energy(p)=mean(abs(x(p:cfg.sps:p+(count-1)*cfg.sps)).^2); end
[~,p]=max(energy); z=x(p:cfg.sps:p+(count-1)*cfg.sps);
scale=median(abs(z)); z=z/max(scale,eps);
z=z.*min(1,3./max(abs(z),eps));
order=2^cfg.bitsPerSymbol; z=z.^order;
window=0.5-0.5*cos(2*pi*(0:numel(z)-1).'/(numel(z)-1));
nfft=2^nextpow2(max(4096,4*numel(z)));
spectrum=abs(fftshift(fft(z.*window,nfft))).^2;
frequency=(-nfft/2:nfft/2-1).'*cfg.symbolRate/nfft;
keep=abs(frequency)<=order*cfg.maxCfoHz;
spectrum(~keep)=0; [~,index]=max(spectrum);
delta=0;
if index>1 && index<nfft
    y=log(max(spectrum(index-1:index+1),realmin));
    denominator=y(1)-2*y(2)+y(3);
    if abs(denominator)>eps, delta=0.5*(y(1)-y(3))/denominator; end
end
cfo=(frequency(index)+max(-0.5,min(0.5,delta))*cfg.symbolRate/nfft)/order;
end

function [starts,scores]=acquireTiles(x,cfg)
reference=cfg.trainingSymbols(:); count=numel(reference);
starts=zeros(0,1); scores=zeros(0,1);
for p=1:cfg.sps
    symbols=x(p:cfg.sps:end);
    if numel(symbols)<count, continue; end
    correlation=conv(symbols,flipud(conj(reference)),'valid');
    energy=conv(abs(symbols).^2,ones(count,1),'valid');
    metric=abs(correlation).^2./max(count*energy,eps);
    peak=metric>=cfg.correlationThreshold & ...
        metric>=[-Inf;metric(1:end-1)] & metric>[metric(2:end);-Inf];
    indices=find(peak);
    starts=[starts;p+(indices-1)*cfg.sps]; %#ok<AGROW>
    scores=[scores;metric(indices)]; %#ok<AGROW>
end
% All oversampling phases observe the same pilot. Keep its best peak once.
[~,order]=sort(scores,'descend'); selected=zeros(0,1);
for k=1:numel(order)
    candidate=order(k);
    if isempty(selected) || all(abs(starts(candidate)-starts(selected))>count*cfg.sps/2)
        selected(end+1,1)=candidate; %#ok<AGROW>
    end
end
starts=starts(selected); scores=scores(selected);
[starts,order]=sort(starts); scores=scores(order);
end

function [bestStart,bestPhase,bestSlope,bestAmplitude,bestQuality,bestEvm]= ...
    refineTraining(x,approximateStart,sps,cfg)
reference=cfg.trainingSymbols(:); n=(0:numel(reference)-1).';
bestQuality=-Inf; bestStart=approximateStart; bestPhase=0;
bestSlope=0; bestAmplitude=0; bestEvm=Inf;
% Fractional sample refinement also corrects the center bias caused by
% acquisition using nominal sps when the observation clock has a mismatch.
for shift=-cfg.sps/2:0.25:cfg.sps/2
    start=approximateStart+shift; positions=start+n*sps;
    if positions(1)<1 || positions(end)>numel(x), continue; end
    y=sampleUniform(x,positions);
    wiped=y.*conj(reference);
    angles=unwrap(angle(wiped));
    weights=max(abs(wiped),0.05*median(abs(wiped)));
    center=sum(weights.*n)/sum(weights);
    slope=sum(weights.*(n-center).*angles)/max(sum(weights.*(n-center).^2),eps);
    gain=mean(wiped.*exp(-1i*slope*n));
    quality=abs(gain)^2/max(mean(abs(y).^2),eps);
    if quality>bestQuality
        bestQuality=quality; bestStart=start; bestPhase=angle(gain);
        bestSlope=slope; bestAmplitude=abs(gain);
        residual=y.*exp(-1i*(bestPhase+slope*n))/max(bestAmplitude,eps)-reference;
        bestEvm=sqrt(mean(abs(residual).^2));
    end
end
end

function y=sampleUniform(x,positions)
% O(number of requested samples), avoiding repeated allocation/scanning of
% the full receive-vector abscissa during fractional timing refinement.
indices=floor(positions); fraction=positions-indices;
right=min(indices+1,numel(x));
y=x(indices).*(1-fraction)+x(right).*fraction;
end

function [corrected,bits,errors]=trackCarrier(data,cfg)
phase=0; frequency=0;
corrected=complex(zeros(size(data))); errors=zeros(size(data));
for k=1:numel(data)
    z=data(k)*exp(-1i*phase);
    if cfg.bitsPerSymbol==1
        decision=1-2*(real(z)<0);
    else
        decision=((1-2*(real(z)<0))+1i*(1-2*(imag(z)<0)))/sqrt(2);
    end
    error=angle(z*conj(decision));
    corrected(k)=z; errors(k)=error;
    frequency=frequency+cfg.carrierBeta*error;
    phase=phase+frequency+cfg.carrierAlpha*error;
end
if cfg.bitsPerSymbol==1
    bits=double(real(corrected)<0);
else
    bits=reshape([double(real(corrected)<0),double(imag(corrected)<0)].',[],1);
end
end

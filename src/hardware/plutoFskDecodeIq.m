function [result,diagnostics]=plutoFskDecodeIq(iq,changes,observer)
% Receiver knows public protocol and tones only, never text/truth/sample offset.
if nargin<2,changes=struct();end
if nargin<3,observer=[];end
assert(isempty(observer)||isa(observer,'function_handle'),'PLUTO:Observer','Observer must be a callback.');
options=plutoFskOptions(changes);here=fileparts(mfilename('fullpath'));
oldPath=path;guard=onCleanup(@()path(oldPath));addpath(fullfile(here,'fskCore'),'-begin');
cfg=fskConfig();iq=double(iq(:));
validateattributes(iq,{'double'},{'vector','nonempty','finite'});
assert(numel(iq)>=4096,'PLUTO:ShortCapture','Capture is too short for acquisition.');
if isempty(observer)
    [offset,acq]=estimateOffset(iq,options,cfg);
else
    [offset,acq,spectrumPlot]=estimateOffset(iq,options,cfg);
    frequency=struct('accepted',acq.accepted,'cfoHz',[],'pairSnrDb',acq.pairSnrDb, ...
        'tone0Hz',[],'tone1Hz',[],'candidateCfoHz',offset);
    if acq.accepted
        frequency.cfoHz=offset;frequency.tone0Hz=acq.observedTone0Hz;frequency.tone1Hz=acq.observedTone1Hz;
        detail=sprintf('频偏估计完成：%+.1f Hz，双音判据 %.2f dB。',offset,acq.pairSnrDb);
    else
        detail=sprintf('未捕获满足门限的双音，候选判据 %.2f dB。',acq.pairSnrDb);
    end
    observer(struct('stage','frequency','detail',detail,'frequency',frequency,'plots',spectrumPlot));
end
diagnostics=struct('radioSampleRate',options.radioSampleRate,'basebandSampleRate',cfg.fs, ...
    'digitalIfHz',options.digitalIfHz, ...
    'receivedSamples',numel(iq),'rmsAmplitude',sqrt(mean(abs(iq).^2)), ...
    'peakAmplitude',max(abs(iq)),'coarseCfoHz',offset,'acquisition',acq,'decimation',10);
if ~acq.accepted
    result=fskDecodeWave(zeros(1000,1),cfg);
    diagnostics.note='No sufficiently strong pair of tones at the public 4 kHz spacing.';
    return;
end
n=(0:numel(iq)-1).';corrected=iq.*exp(-1i*2*pi*(offset+options.digitalIfHz)*n/options.radioSampleRate);
base=resample(corrected,1,10,32,8.6);
if ~isempty(observer)
    observer(struct('stage','baseband','detail',sprintf('已完成去频偏、去数字中频和 10 倍抽取，得到 %d 个基带样本。',numel(base))));
end
h0=exp(1i*2*pi*cfg.f0*(0:cfg.sps-1).'/cfg.fs)/cfg.sps;
h1=exp(1i*2*pi*cfg.f1*(0:cfg.sps-1).'/cfg.fs)/cfg.sps;
e0=abs(filter(h0,1,base)).^2;e1=abs(filter(h1,1,base)).^2;
soft=(e1-e0)./(e1+e0+1e-12);
if ~isempty(observer)
    count=min(numel(soft),round(0.2*cfg.fs));indices=unique(round(linspace(1,count,min(1024,count))));
    observer(struct('stage','demod','detail','双音匹配能量检测完成，显示实际判决量。', ...
        'plots',struct('softTimeSeconds',(indices-1)/cfg.fs,'soft',soft(indices).')));
end
result=fskDecodeWave(soft,cfg);
if ~isempty(observer)
    chosen=find(result.sampleIndices<=min(numel(soft),round(0.2*cfg.fs)));
    if numel(chosen)>1024,chosen=chosen(unique(round(linspace(1,numel(chosen),1024))));end
    transport=struct('complete',false,'message','','validFrameCopies',result.validFrameCount, ...
        'wireComplete',result.complete,'transportCrcPassed',result.complete, ...
        'syncCandidates',result.syncCandidates,'crcRejected',result.crcRejected, ...
        'observedFrameCount',numel(result.observedFrames),'framesTruncated',numel(result.observedFrames)>128, ...
        'frames',observedFrameSummary(result.observedFrames));
    observer(struct('stage','timing_crc','detail',sprintf('定时恢复与帧校验完成：%d 个同步候选，%d 个 CRC 有效帧。',result.syncCandidates,result.validFrameCount), ...
        'plots',struct('decisionTimeSeconds',(result.sampleIndices(chosen).'-1)/cfg.fs,'decisionBits',double(result.bits(chosen).')), ...
        'result',transport));
end
result.wireComplete=result.complete;result.textDecoded=false;result.textDecodeError='';
if result.complete
    result.wireMessage=result.message;
    try
        [result.message,result.transport]=plutoFskUnpackText(result.wireMessage);
        result.textDecoded=true;diagnostics.transport=result.transport;
    catch exception
        result.complete=false;result.message='';result.textDecodeError=exception.message;
        diagnostics.textDecodeError=exception.message;
    end
end
diagnostics.basebandSamples=numel(base);
diagnostics.estimatedClockPpm=median((result.timingPeriodSamples/cfg.sps-1)*1e6);
diagnostics.note='100-sample dual matched-energy detector followed by the existing timing PLL and CRC protocol.';
if ~isempty(observer)
    textResult=struct('complete',result.complete,'message',result.message,'wireComplete',result.wireComplete, ...
        'transportCrcPassed',result.wireComplete,'textDecoded',result.textDecoded,'textDecodeError',result.textDecodeError);
    if result.complete,detail='完整线上消息与文字解码均已通过。';
    elseif result.wireComplete,detail=['线上 CRC 已通过，文字解码失败：' result.textDecodeError];
    else,detail='当前连续片段未恢复通过整条消息 CRC 的完整内容。';end
    observer(struct('stage','text','detail',detail,'result',textResult));
end
end

function [offset,info,spectrumPlot]=estimateOffset(iq,options,cfg)
fs=options.radioSampleRate;N=65536;
if numel(iq)<N,N=2^floor(log2(numel(iq)));end
starts=unique(round(linspace(1,numel(iq)-N+1,min(12,max(1,floor(numel(iq)/N))))));
window=hann(N,'periodic');spectrum=zeros(N,1);
for start=starts
    block=iq(start:start+N-1);block=block-mean(block);
    spectrum=spectrum+abs(fftshift(fft(block.*window,N))).^2;
end
spectrum=spectrum/numel(starts);frequency=(-N/2:N/2-1).'*fs/N;
expected0=options.digitalIfHz+cfg.f0;expected1=options.digitalIfHz+cfg.f1;
valid=abs(frequency-expected0)<=options.maxCfoHz;
% Exclude the receiver's residual DC spur from either candidate tone.
valid=valid & abs(frequency)>150 & abs(frequency+cfg.f1-cfg.f0)>150;
indices=find(valid);
separation=round((cfg.f1-cfg.f0)*N/fs);
indices=indices(indices+separation<=N);
% A small max neighbourhood tolerates FFT-bin rounding and clock drift.
p=movmax(spectrum,[2 2]);
score=min(p(indices),p(indices+separation));
[best,which]=max(score);first=indices(which);
band=abs(frequency-options.digitalIfHz)<=options.maxCfoHz+20000 & abs(frequency)>500;
floorPower=max(median(spectrum(band)),eps);
pairSnr=10*log10(max(best,eps)/floorPower);
f0=refine(first,spectrum,frequency);f1=refine(first+separation,spectrum,frequency);
offset=((f0-expected0)+(f1-expected1))/2;
accepted=isfinite(pairSnr)&&pairSnr>=options.minimumPairSnrDb && ...
    abs((f1-f0)-(cfg.f1-cfg.f0))<=150 && sqrt(mean(abs(iq).^2))>1e-8;
info=struct('accepted',accepted,'pairSnrDb',pairSnr,'observedTone0Hz',f0, ...
    'observedTone1Hz',f1,'observedSeparationHz',f1-f0,'fftLength',N,'windows',numel(starts));
if nargout>2
    edges=round(linspace(1,N+1,min(1024,N)+1));chosen=zeros(numel(edges)-1,1);
    for k=1:numel(chosen)
        range=edges(k):edges(k+1)-1;[~,at]=max(spectrum(range));chosen(k)=range(at);
    end
    spectrumPlot=struct('rfFrequencyHz',frequency(chosen).', ...
        'rfPowerDb',10*log10(max(spectrum(chosen)/(fs*sum(window.^2)),realmin)).');
end
end
function f=refine(index,power,frequency)
range=max(2,index-3):min(numel(power)-1,index+3);
[~,local]=max(power(range));k=range(local);z=log(max(power(k-1:k+1),realmin));
denominator=z(1)-2*z(2)+z(3);delta=0;
if abs(denominator)>eps,delta=max(-0.5,min(0.5,0.5*(z(1)-z(3))/denominator));end
f=frequency(k)+delta*(frequency(2)-frequency(1));
end

function frames=observedFrameSummary(observations)
frames=struct('index',{},'total',{},'length',{},'crcOK',{},'syncErrors',{},'startBit',{},'endBit',{},'messageId',{});
for k=1:min(128,numel(observations))
    f=observations(k);
    frames(end+1)=struct('index',f.sequence,'total',f.total,'length',f.length, ...
        'crcOK',logical(f.crcOK),'syncErrors',f.syncErrors,'startBit',f.startBit, ...
        'endBit',f.endBit,'messageId',double(f.messageId)); %#ok<AGROW>
end
end

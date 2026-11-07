function [out,detail]=demoDecode(iq,mode,observer,trace)
% RX samples + public modulation only. No TX path, message or expected hash.
if nargin<3,observer=@(~,~)[];end
if nargin<4,trace=[];end
detail=struct();
demoInit();iq=double(iq(:));mode=upper(char(mode));
assert(all(isfinite(iq)),'DEMO:Samples','采样包含非有限值。');
if ~isempty(trace)
 block=32768;starts=1:block:numel(iq);levels=zeros(size(starts));
 for b=1:numel(starts),v=iq(starts(b):min(starts(b)+block-1,end));levels(b)=sqrt(mean(abs(v).^2));end
 [~,at]=max(levels);first=starts(at);sample=iq(first:min(first+block-1,end));
 trace.add('01 USB原始采样',{sprintf('本段%d个真实复数样本，%.3f秒；仅使用本机Pluto读回的IQ。',numel(iq),numel(iq)/1e6);sprintf('频谱取本段RMS最大窗口，起点%.6f秒。幅度曲线可看到信号何时进入采集。',(first-1)/1e6)}, ...
  {DemoTrace.plot('line','整段真实接收幅度',(starts-1)/1e6,levels,'本段时间 / s','每32.768ms窗口RMS'),DemoTrace.spectrum(sample,1e6,'真实USB采样频谱')});
end
out=struct('complete',false,'mode',mode,'bytes',uint8([]),'meta',struct(), ...
    'validFrameCopies',0,'cfoHz',NaN,'pilotContrastDb',NaN,'trainingEvm',NaN, ...
    'symbols',[],'frames',struct([]),'reason','未捕获有效帧');
observer('频偏捕获','从本机Pluto IQ估计频偏');
if strcmp(mode,'2FSK')
    if isempty(trace),[r,d]=plutoFskDecodeIq(iq);else,[r,d]=plutoFskDecodeIq(iq,struct(),@(e)demoTraceFsk(trace,e));end
    out.validFrameCopies=r.validFrameCount;
    if d.acquisition.accepted,out.cfoHz=d.coarseCfoHz;end
    out.frames=r.observedFrames;
    if r.complete
        p=regexp(r.message,'^~NATIVE1~([a-f0-9]{12})~([\s\S]*)$','tokens','once');
        if isempty(p),out.reason='收到其他协议文字';return;end
        out.bytes=unicode2native(p{2},'UTF-8').';[~,hash]=advSha256(out.bytes);
        out.meta=struct('nonce',p{1},'kind','text','name','message.txt','bytes',numel(out.bytes),'sha256',hash);
        out.complete=true;out.reason='CRC与本轮无线封装通过';
    end
    observer('帧校验',out.reason);return
end
if numel(iq)<65536||max(abs(iq))<1e-10,return;end
N=min(numel(iq),262144);nfft=2^nextpow2(N);
w=.5-.5*cos(2*pi*(0:N-1)'/(N-1));
f=(0:nfft-1)'*1e6/nfft;
grid=(-50000:1e6/nfft:50000)';
band=(f>=90e3&f<=245e3);found=false;bestContrast=-Inf;bestEst=[];
% Operators start RX before TX. Search later actual windows rather than
% assuming the first quarter-second already contains the transmitter.
for first=1:N:numel(iq)-N+1
 P=abs(fft(iq(first:first+N-1).*w,nfft)).^2;
 a=interp1(f,P,150e3+grid);b=interp1(f,P,190e3+grid);
 [peak,k]=max(min(a,b));offset=grid(k);background=median(P(band));
 contrast=10*log10(max(peak,realmin)/max(background,realmin));
 out.pilotContrastDb=contrast;if contrast<12,continue;end
 est=zeros(1,2);tones=[150e3 190e3];
 for j=1:2
  [~,at]=min(abs(f-(tones(j)+offset)));window=max(2,at-2):min(nfft-1,at+2);
  [~,u]=max(P(window));at=window(u);v=log(max(P(at-1:at+1),realmin));
  delta=.5*(v(1)-v(3))/(v(1)-2*v(2)+v(3));delta=max(-.5,min(.5,delta));
  est(j)=(at-1+delta)*1e6/nfft-tones(j);
 end
 if abs(diff(est))<=30&&contrast>bestContrast
  found=true;bestContrast=contrast;bestEst=est;
 end
end
if ~found,out.reason='整段采样未捕获一致的双校准音';return;end
out.pilotContrastDb=bestContrast;out.cfoHz=mean(bestEst);
try
 [base,tracking]=demoTrackCarrier(iq,out.cfoHz);
catch err
 if strcmp(err.identifier,'DEMO:Carrier'),out.reason='校准音未持续出现；未捕获有效帧';out.cfoHz=NaN;return;end
 rethrow(err)
end
out.acquisitionStartSample=tracking.firstSample;
out.carrierTracking=tracking;out.cfoHz=median(tracking.trackedCfoHz);
if ~isempty(trace)
 trace.add('02 捕获与跟踪频偏',{'公共校准音从真实接收IQ中检测；每个窗口重新估计频差，再积分补偿相位。';sprintf('频偏由%.1f变化到%.1fHz，下面保留原始与平滑后的估计。',tracking.startCfoHz,tracking.endCfoHz)}, ...
  {DemoTrace.plot('line','接收载波频差：原始与平滑',tracking.samplePositions/1e6,[tracking.rawCfoHz(:) tracking.trackedCfoHz(:)],'本段时间 / s','频偏 / Hz'),DemoTrace.plot('line','校准音检测强度',tracking.samplePositions/1e6,tracking.contrastDb,'本段时间 / s','相对背景 / dB')});
end
observer('匹配滤波',sprintf('跟踪频偏 %.1f → %.1f Hz；去中频、降采样、RRC匹配滤波',tracking.startCfoHz,tracking.endCfoHz));
base=resample(base,6,125,32,8.6);cfg=advPskConfig(mode);
if ~isempty(trace)
 trace.add('03 去中频与降采样',{'去除100kHz中频和实测频偏，再由1MHz降采样到48kHz。';'图中基带信号来自本段捕获后的实际计算结果。'},DemoTrace.signal(base,cfg.Fs,'校频后的接收基带'));
end
h=rcosdesign(cfg.rolloff,cfg.filterSpan,cfg.sps,'sqrt').';matched=conv(base,h/sqrt(cfg.sps));
if ~isempty(trace)
 trace.add('04 RRC匹配滤波',{'接收RRC与发送RRC配对，压制带外噪声并形成码元判决波形。';'叠加图尚未按恢复定时对齐；下一步才由公共训练序列确定采样位置。'}, ...
  {DemoTrace.spectrum(matched,cfg.Fs,'匹配滤波后频谱'),DemoTrace.eye(matched,cfg.sps,'匹配滤波波形叠加 / 未对齐定时')});
end
observer('同步与解调','PN训练、码元定时、载波PLL、SECDED、交织和CRC重组');
r=advReceivePsk(matched,cfg);detail=r;out.validFrameCopies=r.validFrameCount;
out.syncCandidates=r.syncCandidates;out.headerRejected=r.headerRejected;
out.fecRejected=r.fecRejected;out.crcRejected=r.crcRejected;
out.estimatedClockPpm=r.estimatedClockPpm;
out.symbols=r.correctedSymbols(1:min(end,2048));out.frames=r.observedFrames;
if ~isempty(r.tiles),out.trainingEvm=median([r.tiles.trainingEvm]);end
if isfinite(r.coarseCfoHz),out.cfoHz=out.cfoHz+r.coarseCfoHz;end
if ~isempty(trace)
 tiles=r.tiles;time=[];correlation=[];evm=[];
 if ~isempty(tiles),time=([tiles.sampleIndex]-1)/cfg.Fs;correlation=[tiles.correlation];evm=[tiles.trainingEvm];end
 trace.add('05 PN同步与码元定时',{sprintf('实际接受%d组训练块，估计时钟偏差%.2fppm。',numel(tiles),r.estimatedClockPpm);'每个点对应一个实际接受的PN训练块：相关度衡量对齐程度，EVM衡量训练符号误差。'}, ...
  {DemoTrace.plot('line','已接受训练块的相关度',time,correlation,'匹配滤波序列时间 / s','相关度'),DemoTrace.plot('line','训练块EVM',time,evm,'匹配滤波序列时间 / s','EVM（比值）')});
 trace.add('06 载波PLL与比特判决',{'用训练块消除残余频率和相位误差，再逐码元PLL跟踪、判决比特。';'星座来自实际恢复码元；比特来自本机接收判决，未读取发送原文。'}, ...
  {DemoTrace.constellation(r.correctedSymbols,'真实恢复码元星座'),DemoTrace.bits(r.bits,'本机实际判决比特')});
 frames=r.observedFrames;seq=[];copies=[];
 if ~isempty(frames)
  good=frames([frames.crcOK]);if ~isempty(good),seq=1:max([good.total]);copies=arrayfun(@(s)sum([good.sequence]==s),seq);end
 end
 trace.add('07 解交织、纠错与CRC',{sprintf('CRC有效副本%d；帧头拒绝%d，纠错拒绝%d，CRC拒绝%d。',r.validFrameCount,r.headerRejected,r.fecRejected,r.crcRejected);'分片柱图记录每一片通过CRC的副本数；缺片会显示为0。'}, ...
  {DemoTrace.plot('bar','各分片CRC有效副本',seq,copies,'分片编号','有效副本数'),DemoTrace.plot('bar','校验统计：有效 / 帧头拒绝 / FEC拒绝 / CRC拒绝',1:4,[r.validFrameCount r.headerRejected r.fecRejected r.crcRejected],'统计类别 1 / 2 / 3 / 4','次数')});
end
if ~r.complete
 if r.validFrameCount>0
  out.reason=sprintf('CRC有效副本%d；未完整恢复，缺分片 %s',r.validFrameCount,mat2str(r.missingFrames));
 else
  out.reason=sprintf('未恢复有效帧：同步候选%d，帧头拒绝%d，FEC拒绝%d',r.syncCandidates,r.headerRejected,r.fecRejected);
 end
end
if r.complete
    try
        [~,out.meta,out.bytes]=demoEnvelope('unpack',r.bytes);out.complete=true;
        out.reason='分片、CRC与文件SHA-256全部通过';
    catch err,out.reason=err.message;end
end
observer('内容恢复',out.reason);
if ~isempty(trace)
 text={out.reason};if out.complete,text=[text;{['无线标记 ' out.meta.nonce];['文件SHA256 ' out.meta.sha256];'接收窗口显示的文字/图片，由这里的恢复字节写成。'}];end
 trace.add('08 重组与内容恢复',text,{DemoTrace.bytes(out.bytes,'本次实际恢复的内容字节'),DemoTrace.bits(advBytesToBits(out.bytes),'恢复字节的二进制表示')});
end
end

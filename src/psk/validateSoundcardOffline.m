function report=validateSoundcardOffline(outputDir)
% Save reproducible audio-line simulation evidence. No playback/recording.
if nargin<1,outputDir=fullfile(fileparts(fileparts(mfilename('fullpath'))),'声卡离线验证');end
if ~isfolder(outputDir),mkdir(outputDir);end
cfg=advSoundcardConfig();cfg.protocol.fec=true;
bytes=uint8(['Soundcard wired-channel SOFTWARE simulation. ' ...
    'No speaker, microphone, cable, or RF measurement was used. ' ...
    'Unknown delay, polarity, amplitude, bandwidth, noise and sample-clock drift are tested.']).';
bytes=[bytes;uint8(10);bytes]; % Exceed the fixed 256-byte fragment boundary.
rng(932,'twister');
[tx,info]=advSoundcardTransmit(bytes,cfg,fullfile(outputDir,'待连线发送_48kHz_2FSK.wav'));
names={'ideal','delay_gain','noise_18dB','bandlimit_2p5_10k','clock_minus2000ppm', ...
    'clock_plus2000ppm','combined','right_channel_only','silence','noise_only','severe_lowpass'};
expected=[true true true true true true true true false false false];
rows=repmat(struct('name','','complete',false,'equalBytes',false,'validFrames',0, ...
    'correctedErrors',0,'expectedComplete',false,'passed',false,'samples',0),numel(names),1);
best=[];bestAudio=[];
for k=1:numel(names)
    x=tx;
    switch names{k}
        case 'delay_gain',x=[zeros(2197,1);-0.08*x;zeros(400,1)];
        case 'noise_18dB',x=x+sqrt(mean(tx.^2)/10^(18/10))*randn(size(x));
        case 'bandlimit_2p5_10k',x=filter(fir1(96,[2500 10000]/(cfg.fs/2)),1,x);
        case 'clock_minus2000ppm',x=clockChange(x,-2000);
        case 'clock_plus2000ppm',x=clockChange(x,2000);
        case 'combined'
            x=filter(fir1(96,[2500 10000]/(cfg.fs/2)),1,x);
            x=clockChange(x,1500);x=-0.17*x;
            x=x+sqrt(mean(x.^2)/10^(20/10))*randn(size(x));
            x=[zeros(1783,1);x;zeros(900,1)];
        case 'right_channel_only',x=[zeros(size(x)) x];
        case 'silence',x=zeros(size(x));
        case 'noise_only',x=0.1*randn(size(x));
        case 'severe_lowpass',x=filter(fir1(192,2000/(cfg.fs/2)),1,x)+0.03*randn(size(x));
    end
    r=advSoundcardReceive(x,cfg);
    equal=r.complete&&isequal(r.bytes,bytes);
    rows(k)=struct('name',names{k},'complete',logical(r.complete),'equalBytes',equal, ...
        'validFrames',r.validFrameCount,'correctedErrors',r.correctedErrors, ...
        'expectedComplete',expected(k),'passed',logical(equal==expected(k)&&r.complete==expected(k)), ...
        'samples',size(x,1));
    if strcmp(names{k},'combined'),best=r;bestAudio=x;end
end
[quantized,fs]=audioread(fullfile(outputDir,'待连线发送_48kHz_2FSK.wav'));
q=advSoundcardReceive(quantized,cfg);
report=struct('scope','Offline simulation only; physical soundcard cable NOT tested', ...
    'audioDeviceUsed',false,'config',cfg,'transmit',info,'cases',rows, ...
    'wavRoundtripPassed',logical(fs==cfg.fs&&q.complete&&isequal(q.bytes,bytes)), ...
    'allPassed',logical(all([rows.passed])&&q.complete&&isequal(q.bytes,bytes)));
fid=fopen(fullfile(outputDir,'声卡离线结果.json'),'w','n','UTF-8');
assert(fid>=0,'ADV:SoundcardOutput','Cannot open validation JSON.');
closer=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));clear closer
save(fullfile(outputDir,'声卡离线数据.mat'),'cfg','bytes','tx','bestAudio','best','report');
audiowrite(fullfile(outputDir,'离线组合损伤接收_非实录.wav'),bestAudio,cfg.fs,'BitsPerSample',16);
if best.complete
    fid=fopen(fullfile(outputDir,'恢复文本.txt'),'wb');fwrite(fid,best.bytes,'uint8');fclose(fid);
end
fig=figure('Visible','off','Color','w','Position',[0 0 1200 740]);
subplot(2,1,1);t=(0:numel(best.audio.normalizedWave)-1)'/cfg.fs;
plot(t,best.audio.normalizedWave);hold on;idx=best.audio.sampleIndices;
scatter(t(idx),best.audio.normalizedWave(idx),10,'r','filled');xlim([0.12 0.16]);ylim([-1.2 1.2]);
xlabel('Time (s)');ylabel('FSK signed energy');title('Offline combined channel: receive-driven PLL sample points');grid on;
subplot(2,1,2);plot(t(idx),(best.audio.timingPeriodSamples/cfg.sps-1)*1e6);
xlabel('Time (s)');ylabel('Estimated sample-clock offset (ppm)');grid on;
exportgraphics(fig,fullfile(outputDir,'声卡同步与钟偏.png'));close(fig);
fprintf('SOUNDCARD_OFFLINE: %d/%d case expectations, WAV=%d, no physical audio I/O\n', ...
    sum([rows.passed]),numel(rows),report.wavRoundtripPassed);
assert(report.allPassed,'ADV:SoundcardOfflineFailed','See retained soundcard case results.');
end
function y=clockChange(x,ppm)
y=interp1((0:numel(x)-1)',x,(0:1/(1+ppm*1e-6):numel(x)-1)','linear');
end

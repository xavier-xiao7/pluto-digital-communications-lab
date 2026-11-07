function evidence=createAdvancedFigures(destination,snapshotPath)
% Plots actual Simulink samples and RX-estimated times, never TX timing.
here=fileparts(mfilename('fullpath'));base=fileparts(here);
if nargin<1,destination=fullfile(base,'图表');end
if nargin<2,snapshotPath=fullfile(base,'验证','advanced_snapshots.mat');end
if ~isfolder(destination),mkdir(destination);end
s=load(snapshotPath);s=s.snapshots;evidence=struct();
for mode={'BPSK','QPSK'}
 name=mode{1};v=s.([name '_combined']);c=v.cfg;r=v.rx;
 x=v.out.rxWave.Data(:);tileNumber=min(3,numel(r.tiles));tile=r.tiles(tileNumber);sps=r.estimatedSps;
 n=(0:numel(x)-1).';x=x.*exp(-1i*2*pi*r.coarseCfoHz*n/c.Fs);
 slope=(tile.fineCfoHz-r.coarseCfoHz)*2*pi*sps/c.Fs;
 x=x.*exp(-1i*(tile.phaseRadians+slope*((1:numel(x)).'-tile.sampleIndex)/sps))/tile.amplitude;
 positions=tile.sampleIndex+(c.trainingLength+(0:c.dataSymbolsPerTile-1)).'*sps;
 samples=interp1((1:numel(x)).',x,positions,'linear');
 change=find(abs(diff(real(samples)))>0.6,1);if isempty(change),change=50;end;first=max(3,min(c.dataSymbolsPerTile-15,change-4));shown=first:first+10;
 fig=figure('Visible','off','Position',[50 50 1000 850]);tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
 nexttile([1 2]);segment=floor(positions(shown(1))-sps):ceil(positions(shown(end))+sps);
 plot((segment-positions(shown(1)))/sps,real(x(segment)),'LineWidth',1);hold on;
 stem((positions(shown)-positions(shown(1)))/sps,real(samples(shown)),'r','filled','MarkerSize',3);
 grid on;xlabel('Time relative to first shown sample / symbols');ylabel('Normalized I');
 title([name ': actual matched-filter waveform and recovered sample instants']);
 legend('Pilot-corrected waveform before decision PLL','RX-estimated sample points','Location','best');
 nexttile;hold on;offsets=linspace(-sps,sps,129).';
 for j=10:110
  y=interp1((1:numel(x)).',real(x),positions(j)+offsets,'linear');plot(offsets/sps,y,'Color',[.12 .35 .7 .18]);
 end
 xline(0,'r--');grid on;xlabel('Symbols from recovered sample');ylabel('Normalized I');title('Recovered timing eye 101 traces');
 nexttile;hold on;
 for j=10:110
  y=interp1((1:numel(x)).',real(x),(1+round((positions(j)-1)/c.sps)*c.sps)+offsets,'linear');plot(offsets/sps,y,'Color',[.6 .3 .08 .18]);
 end
 xline(0,'r--');grid on;xlabel('Symbols from nominal-grid sample');ylabel('Normalized I');title('Fixed nominal clock grid starting at sample 1');
 nexttile;raw=v.out.rxWave.Data(:);raw=interp1((1:numel(raw)).',raw,positions,'linear');
 plot(real(raw),imag(raw),'.','MarkerSize',5);axis equal;grid on;xlabel('I');ylabel('Q');title('Matched samples before carrier correction');
 nexttile;z=r.correctedSymbols((tileNumber-1)*c.dataSymbolsPerTile+(1:c.dataSymbolsPerTile));plot(real(z),imag(z),'.','MarkerSize',4);axis equal;grid on;xlabel('I');ylabel('Q');title('RX pilot and decision PLL corrected symbols');
 exportgraphics(fig,fullfile(destination,[name '_同步眼图星座.png']),'Resolution',150);close(fig);
 evidence.(name)=struct('samplePointCount',numel(positions),'estimatedSps',sps,'source','Actual Simulink rxWave and RX tile estimate; nominal-eye grid starts at received sample 1 and uses public nominal sps; both eyes use the same waveform and carrier correction.');
end
fig=figure('Visible','off','Position',[50 50 1000 650]);tiledlayout(2,1,'TileSpacing','compact');
nexttile;hold on;
for shape={'combined','rectangular'}
 v=s.(['QPSK_' shape{1}]);x=v.out.txSignal.Data(:);
 [p,f]=pwelch(x,hann(4096),2048,16384,v.cfg.Fs,'centered');
 plot(f/1000,10*log10(p/max(p)),'LineWidth',1);
end
grid on;xlim([0 20]);ylim([-85 5]);xlabel('Frequency / kHz');ylabel('PSD normalized to own peak / dB');
title('Actual transmitted signal PSD at equal symbol rate');legend('RRC rolloff 0.5','Rectangular','Location','best');
nexttile;hold on;details=struct();
for shape={'rrc','rectangular'}
 c=advExperimentConfig(struct('pulseShape',shape{1}));impulse=conv(c.txFilter,c.rxFilter);center=(numel(impulse)+1)/2;
 assert(center==round(center));radius=floor(min(center-1,numel(impulse)-center)/c.sps);indices=center+(-radius:radius)*c.sps;
 vals=impulse(indices)/impulse(center);stem((indices-center)/c.sps,vals,'filled','MarkerSize',3);
 off=vals(indices~=center);details.(shape{1})=struct('peak',impulse(center),'totalGroupDelaySamples',center-1,'maximumOffCenterSymbolResponse',max([0 abs(off)]),'symbolOffsetsChecked',(indices-center)/c.sps);
end
grid on;xlabel('Symbol-spaced offset');ylabel('Combined pulse response / main tap');legend('RRC finite span','Rectangular matched','Location','best');title('Independent combined-filter impulse response and residual ISI');
exportgraphics(fig,fullfile(destination,'成型频谱与码间干扰.png'),'Resolution',150);close(fig);evidence.filterCheck=details;
% Recovered media are loaded from the output of the receive/decode path.
mediaDir=fileparts(snapshotPath);src=fullfile(mediaDir,'发送素材');dst=fullfile(mediaDir,'恢复文件','QPSK');
if isfile(fullfile(dst,'synthetic_tones_8k_pcm16.wav'))
 a=imread(fullfile(src,'synthetic_pattern_32x32.png'));b=imread(fullfile(dst,'synthetic_pattern_32x32.png'));
 [u,fs]=audioread(fullfile(src,'synthetic_tones_8k_pcm16.wav'));[w,fs2]=audioread(fullfile(dst,'synthetic_tones_8k_pcm16.wav'));
 assert(isequal(a,b)&&isequal(u,w)&&fs==fs2);
 fig=figure('Visible','off','Position',[50 50 950 650]);tiledlayout(2,2,'TileSpacing','compact');
 nexttile;image(a);axis image off;title('Source PNG pixels');nexttile;image(b);axis image off;title('Received and decoded PNG pixels');
 nexttile;plot((0:numel(u)-1)/fs,u);grid on;xlabel('Time / s');title('Source PCM audio samples');nexttile;plot((0:numel(w)-1)/fs2,w);grid on;xlabel('Time / s');title('Received PCM audio samples identical');
 exportgraphics(fig,fullfile(destination,'图片与音频恢复.png'),'Resolution',150);close(fig);
 evidence.media=struct('imagePixelEquality',true,'pcmSampleEquality',true,'audioSampleRate',fs,'physicalAudioUsed',false);
end
mdl='stuAdvancedSimulation';load_system(fullfile(here,[mdl '.slx']));
print(['-s' mdl],'-dpng','-r140',fullfile(destination,'Simulink总模型.png'));
print(['-s' mdl '/PSK and pulse shaping'],'-dpng','-r140',fullfile(destination,'Simulink调制与成型.png'));
print(['-s' mdl '/Downconversion and matched filter'],'-dpng','-r140',fullfile(destination,'Simulink解调与匹配滤波.png'));
fid=fopen(fullfile(destination,'figure_evidence.json'),'w','n','UTF-8');fwrite(fid,jsonencode(evidence,PrettyPrint=true),'char');fclose(fid);
end

function summary=validateFskExperiment(destination)
% Reproducible end-to-end Simulink validation; saves failures as evidence.
here=fileparts(mfilename('fullpath'));oldpath=path;cleanup=onCleanup(@()path(oldpath));addpath(here,'-begin');
if nargin<1,destination=fullfile(fileparts(here),'验证');end
if ~isfolder(destination),mkdir(destination);end
set(0,'DefaultFigureVisible','off');
base=fskConfig();longText=repmat('Lab packet 0123456789 ABC xyz. ',1,8);
cases=struct('name',{},'message',{},'cfg',{},'required',{});
cases(end+1)=makeCase('ideal_single','A','ideal',25,true,base);
cases(end+1)=makeCase('ideal_multiframe',longText,'ideal',25,true,base);
cases(end+1)=makeCase('ideal_all_ASCII',char(0:127),'ideal',25,true,base);
cases(end+1)=makeCase('awgn_25dB',longText,'awgn',25,true,base);
cases(end+1)=makeCase('rician_original',longText,'rician',25,true,base);
cases(end+1)=makeCase('teacher_combined_25dB',longText,'combined',25,true,base);
for phase=[0.7 pi 5.2]
 c=makeCase(sprintf('phase_%.2f',phase),'Unknown carrier phase is removed by energy detection.','combined',25,true,base);c.cfg.phaseOffsetRad=phase;cases(end+1)=c;
end
for offset=[100 300 800]
 c=makeCase(sprintf('frequency_offset_%dHz',offset),longText,'combined',25,false,base);c.cfg.frequencyOffsetHz=offset;cases(end+1)=c;
end
for eb=[0 4 8 12 16 20 25]
 for seed=[67 101 203]
  c=makeCase(sprintf('combined_EbNo_%d_seed_%d',eb,seed),'Noise sweep: Lab 2FSK 0123456789 abcdefghijklmnop.','combined',eb,false,base);c.cfg.awgnSeed=seed;c.cfg.fadingSeed=seed+6;cases(end+1)=c;
 end
end
records=struct([]);defaultData=[];
for k=1:numel(cases)
 item=cases(k);fprintf('CASE %d/%d %s\n',k,numel(cases),item.name);
 rec=struct('name',item.name,'channelMode',item.cfg.channelMode,'ebNo',item.cfg.ebNo,'awgnSeed',item.cfg.awgnSeed, ...
  'required',item.required,'messageComplete',false,'validFrameCopies',0,'expectedFrameCopies',0,'crcRejected',0,'error','');
 try
  [out,rx,cfg,truth]=runFskExperiment(item.message,item.cfg);
  rec.messageComplete=rx.complete&&strcmp(rx.message,item.message);rec.validFrameCopies=rx.validFrameCount;
  rec.expectedFrameCopies=truth.expectedCopies;rec.crcRejected=rx.crcRejected;
  rec.sampleCount=numel(out.rxWave.Data);rec.symbolCount=numel(rx.bits);
  rec.frequencyOffsetHz=cfg.frequencyOffsetHz;rec.phaseOffsetRad=cfg.phaseOffsetRad;
  tx=out.txSignal.Data(:);afterNoise=out.awgnSignal.Data(:);
  rec.measuredNoiseVariance=mean(abs(afterNoise-tx).^2);rec.expectedNoiseVariance=cfg.sps/10^(cfg.ebNo/10);
  if ismember(cfg.channelMode,{'ideal','rician'}),rec.expectedNoiseVariance=0;end
  assert(abs(rec.measuredNoiseVariance-rec.expectedNoiseVariance)<max(1e-12,0.03*rec.expectedNoiseVariance), ...
   'Complex AWGN variance differs from the Eb/N0 conversion by more than 3 percent.');
  save(fullfile(destination,[item.name '.mat']),'cfg','truth','rx','out','-v7');
  if strcmp(item.name,'teacher_combined_25dB'),defaultData=struct('out',out,'rx',rx,'cfg',cfg,'truth',truth);end
 catch e
  rec.messageComplete=false;rec.error=getReport(e,'extended','hyperlinks','off');rec.sampleCount=0;rec.symbolCount=0;
  rec.frequencyOffsetHz=NaN;rec.phaseOffsetRad=NaN;rec.measuredNoiseVariance=NaN;rec.expectedNoiseVariance=NaN;
 end
 if isempty(records),records=rec;else,records(k)=rec;end %#ok<AGROW>
 fprintf('RESULT complete=%d valid=%d/%d %s\n',rec.messageComplete,rec.validFrameCopies,rec.expectedFrameCopies,rec.error);
 writeJson(fullfile(destination,'end_to_end.json'),records);
end
assert(~isempty(defaultData),'No default experiment result is available.');
clock=clockStudy(defaultData,destination);
makeFigures(defaultData,records,clock,destination);
summary=struct('matlabVersion',version,'model','teacher-derived stuFskSimulation', ...
 'requiredCasesPassed',all([records([records.required]).messageComplete]),'caseCount',numel(records), ...
 'fullMessageSuccesses',sum([records.messageComplete]),'failedCases',{{records(~[records.messageComplete]).name}}, ...
 'clockStudy',clock,'rfHardwareTested',false);
writeJson(fullfile(destination,'validation_summary.json'),summary);
assert(summary.requiredCasesPassed,'One or more required baseline cases failed; see end_to_end.json.');
end
function c=makeCase(name,message,mode,eb,required,cfg)
cfg.channelMode=mode;cfg.ebNo=eb;
c=struct('name',name,'message',message,'cfg',cfg,'required',required);
end
function writeJson(file,data)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);guard=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(data,PrettyPrint=true),'char');
end
function records=clockStudy(data,dest)
cfg=data.cfg;w=data.out.channelSignal.Data(:);records=struct([]);
for ppm=[-2000 -500 0 500 2000]
 t=(1:1/(1+ppm*1e-6):numel(w)).';v=interp1((1:numel(w)).',w,t,'linear');
 e0=abs(filter(exp(1i*2*pi*cfg.f0*(0:cfg.sps-1)/cfg.fs)/cfg.sps,1,v)).^2;
 e1=abs(filter(exp(1i*2*pi*cfg.f1*(0:cfg.sps-1)/cfg.fs)/cfg.sps,1,v)).^2;
 z=(e1-e0)./(e1+e0+1e-12);
 cfg.timingMode='pll';tracked=fskDecodeWave(z,cfg);
 cfg.timingMode='fixed';fixed=fskDecodeWave(z,cfg);
 entry=struct('ppm',ppm,'pllComplete',tracked.complete&&strcmp(tracked.message,data.truth.message), ...
  'fixedComplete',fixed.complete&&strcmp(fixed.message,data.truth.message), ...
  'pllValidFrames',tracked.validFrameCount,'fixedValidFrames',fixed.validFrameCount, ...
  'expectedFrameCopies',data.truth.expectedCopies,'estimatedPeriod',median(tracked.timingPeriodSamples(end-min(1000,end-1):end)), ...
  'injectedPeriod',cfg.sps*(1+ppm*1e-6));
 if isempty(records),records=entry;else,records(end+1)=entry;end %#ok<AGROW>
 save(fullfile(dest,sprintf('clock_%dppm.mat',ppm)),'cfg','z','tracked','fixed','ppm','-v7');
end
writeJson(fullfile(dest,'clock_recovery.json'),records);
end
function makeFigures(data,records,clock,dest)
cfg=data.cfg;rx=data.rx;z=rx.normalizedWave;idx=rx.sampleIndices;
f=figure('Visible','off','Color','w','Position',[50 50 1300 850]);
subplot(3,1,1);n=1:min(3000,numel(z));plot((n-1)/cfg.fs*1000,real(data.out.txSignal.Data(n)));xlabel('Time (ms)');ylabel('Real TX');title('Teacher-derived 2FSK: complex tones 8 / 12 kHz, constant power');grid on;
subplot(3,1,2);n=15000:min(17000,numel(z));plot((n-1)/cfg.fs*1000,z(n));hold on;s=idx(idx>=n(1)&idx<=n(end));stem((s-1)/cfg.fs*1000,z(s),'.','MarkerSize',10);yline(0,'--');ylim([-1.2 1.2]);xlabel('Time (ms)');ylabel('(E1-E0)/(E1+E0)');title('Actual energy-detector waveform and recovered symbol samples');grid on;
subplot(3,1,3);plot((idx-1)/cfg.fs,rx.timingPeriodSamples);yline(cfg.sps,'--');xlabel('Time (s)');ylabel('Samples / symbol');title('Second-order timing loop: estimated symbol period');grid on;
exportgraphics(f,fullfile(dest,'waveform_and_timing.png'),'Resolution',150);close(f);
% The same received waveform is folded around two clocks. No filtering gain is implied.
f=figure('Visible','off','Color','w','Position',[50 50 1200 460]);
for p=1:2
 subplot(1,2,p);hold on;
 if p==1,centers=(round(cfg.fixedPhaseSamples):cfg.sps:numel(z)).';label='Free-running nominal-clock eye';else,centers=idx;label='Recovered-clock eye (same received samples)';end
 centers=centers(centers>15000 & centers<numel(z)-cfg.sps);centers=centers(1:min(250,numel(centers)));
 for k=1:numel(centers),span=-cfg.sps:cfg.sps;plot(span/cfg.sps,z(centers(k)+span),'Color',[0.15 0.45 0.8 0.14]);end
 xline(0,'r--');ylim([-1.2 1.2]);xlabel('Offset from selected sample (symbols)');ylabel('Soft energy metric');title(label);grid on;
end
exportgraphics(f,fullfile(dest,'timing_eye_comparison.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[50 50 1200 460]);
subplot(1,2,1);values=[0 4 8 12 16 20 25];rate=zeros(size(values));
for k=1:numel(values),sel=startsWith({records.name},sprintf('combined_EbNo_%d_seed_',values(k)));rate(k)=mean([records(sel).messageComplete]);end
plot(values,rate,'-o','LineWidth',1.5);ylim([-0.05 1.05]);xlabel('Eb/N0 (dB)');ylabel('Complete-message fraction (3 seeds each)');title('AWGN then original Rician; repetitions=2');grid on;
subplot(1,2,2);bar([clock.ppm],[clock.fixedValidFrames;clock.pllValidFrames].');xlabel('Injected sample-clock error (ppm)');ylabel('CRC-valid frame copies');legend('Fixed clock','Recovered clock','Location','best');title('Offline resampling of actual Simulink channel output');grid on;
exportgraphics(f,fullfile(dest,'channel_and_clock_comparison.png'),'Resolution',150);close(f);
f=figure('Visible','off','Color','w','Position',[50 50 1200 520]);
tx=data.out.txSignal.Data(:);channel=data.out.channelSignal.Data(:);
[pt,freq]=pwelch(tx,hann(2048),1024,8192,cfg.fs,'centered');
[pr,~]=pwelch(channel,hann(2048),1024,8192,cfg.fs,'centered');
plot(freq/1000,10*log10(pt+eps),'LineWidth',1.2);hold on;plot(freq/1000,10*log10(pr+eps),'LineWidth',1.0);
xline(cfg.f0/1000,'--');xline(cfg.f1/1000,'--');xlim([-25 25]);xlabel('Frequency (kHz), Fs=100 kHz');ylabel('PSD (dB / Hz)');
title('Actual complex 2FSK waveform spectrum before / after teacher channel');legend('TX','After AWGN and Rician','Location','best');grid on;
exportgraphics(f,fullfile(dest,'fsk_spectrum.png'),'Resolution',150);close(f);
end

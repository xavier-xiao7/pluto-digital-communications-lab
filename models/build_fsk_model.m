function build_fsk_model()
root=fileparts(fileparts(mfilename('fullpath')));
here=fullfile(root,'src','fsk');
mdl='stuFskSimulation';target=fullfile(here,[mdl '.slx']);
if bdIsLoaded(mdl),close_system(mdl,0);end
createLabModel(mdl);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','auto','ReturnWorkspaceOutputs','on', ...
 'SaveOutput','off','SaveTime','off','StopTime','(numel(txWave)-cfg.frameSamples)/cfg.fs');
src=sprintf('Signal From\nWorkspace');awgn=sprintf('AWGN\nChannel');fade='SISO Fading Channel1';iq=sprintf('Complex to\nReal-Imag');
set_param([mdl '/' src],'X','txWave','Ts','1/cfg.fs','nsamps','cfg.frameSamples', ...
 'OutputAfterFinalValue','Setting to zero','Position',[30 165 130 215]);
addModulator([mdl '/2FSK Modulator']);set_param([mdl '/2FSK Modulator'],'Position',[195 165 330 215]);
set_param([mdl '/' awgn],'Position',[405 165 495 215], ...
 'LegacyMode','off','NoiseMethod','Signal to noise ratio  (Eb/No)','EbNo','cfg.ebNo', ...
 'BitsPerSymbol','1','SignalPower','1','SpecifySymbolPeriod','off','SamplesPerSymbol','cfg.sps', ...
 'RandomStream','mt19937ar with seed','Seed','cfg.awgnSeed','SimulateUsing','Interpreted execution');
set_param([mdl '/' fade],'Position',[560 150 690 230],'Seed','cfg.fadingSeed');
addDemodulator([mdl '/2FSK Energy Detector']);set_param([mdl '/2FSK Energy Detector'],'Position',[765 160 915 220]);
set_param([mdl '/To Workspace1'],'VariableName','rxWave','SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf','Position',[1000 170 1110 210]);
set_param([mdl '/' iq],'Position',[745 325 805 365]);
set_param([mdl '/Scope'],'NumInputPorts','2','OpenAtSimulationStart','off','Position',[1000 315 1050 365]);
set_param([mdl sprintf('/Spectrum\nAnalyzer')],'Position',[420 320 490 370]);
scopeConfig=get_param([mdl sprintf('/Spectrum\nAnalyzer')],'ScopeConfiguration');scopeConfig.OpenAtSimulationStart=false;
set_param([mdl sprintf('/Spectrum\nAnalyzer')],'SampleRate','cfg.fs','ChannelNames',"{'2FSK TX'}");
wire(mdl,[src '/1'],'2FSK Modulator/1');wire(mdl,'2FSK Modulator/1',[awgn '/1']);
wire(mdl,[awgn '/1'],[fade '/1']);wire(mdl,[fade '/1'],'2FSK Energy Detector/1');
wire(mdl,'2FSK Energy Detector/1','To Workspace1/1');
wire(mdl,[fade '/1'],[iq '/1']);wire(mdl,[iq '/1'],'Scope/1');wire(mdl,'2FSK Energy Detector/1','Scope/2');
wire(mdl,'2FSK Modulator/1',sprintf('Spectrum\nAnalyzer/1'));
addLog(mdl,'TX samples','txSignal',[205 300 305 340],'2FSK Modulator/1');
addLog(mdl,'Channel samples','channelSignal',[570 310 685 350],[fade '/1']);
addLog(mdl,'After AWGN','awgnSignal',[420 420 520 460],[awgn '/1']);
note=Simulink.Annotation(mdl,'2FSK: 100 ksample/s, 1 kbit/s, tones 8 / 12 kHz');note.Position=[35 35];
set_param(mdl,'InitFcn','commLabModelCallbacks(''init'',''2FSK'');','StopFcn','commLabModelCallbacks(''stop'',''2FSK'');','ReturnWorkspaceOutputs','off');
save_system(mdl,target);fprintf('BUILT %s\n',target);
end
function wire(mdl,a,b),add_line(mdl,a,b,'autorouting','on');end
function addLog(mdl,name,var,pos,source)
add_block('simulink/Sinks/To Workspace',[mdl '/' name],'VariableName',var,'SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf','Position',pos);
wire(mdl,source,[name '/1']);
end
function addModulator(p)
add_block('built-in/Subsystem',p);add_block('simulink/Ports & Subsystems/In1',[p '/NRZ bits'],'Position',[25 110 55 130]);
add_block('simulink/Ports & Subsystems/Out1',[p '/Complex 2FSK'],'Position',[655 175 685 195]);
add_block('simulink/Sources/Constant',[p '/One'],'Value','1','Position',[85 30 115 60]);
add_block('simulink/Math Operations/Sum',[p '/One minus bit'],'Inputs','+-','Position',[165 50 195 90]);
wire(p,'One/1','One minus bit/1');wire(p,'NRZ bits/1','One minus bit/2');
for k=0:1
 name=sprintf('Tone %d',k);prod=sprintf('Select tone %d',k);y=100+180*k;
 add_block('dspsrcs4/Sine Wave',[p '/' name],'Amplitude','1','Frequency',sprintf('cfg.f%d+cfg.frequencyOffsetHz',k), ...
  'Phase','cfg.phaseOffsetRad','OutComplex','Complex','SampleTime','1/cfg.fs','SamplesPerFrame','cfg.frameSamples','Position',[180 y+25 330 y+65]);
 add_block('simulink/Math Operations/Product',[p '/' prod],'Position',[420 y-25 450 y+15]);
 wire(p,[name '/1'],[prod '/2']);
 if k==0,wire(p,'One minus bit/1',[prod '/1']);else,wire(p,'NRZ bits/1',[prod '/1']);end
end
add_block('simulink/Math Operations/Sum',[p '/Sum tones'],'Inputs','++','Position',[560 165 590 205]);
wire(p,'Select tone 0/1','Sum tones/1');wire(p,'Select tone 1/1','Sum tones/2');wire(p,'Sum tones/1','Complex 2FSK/1');
end
function addDemodulator(p)
add_block('built-in/Subsystem',p);add_block('simulink/Ports & Subsystems/In1',[p '/Received complex samples'],'Position',[25 160 55 180]);
add_block('simulink/Ports & Subsystems/Out1',[p '/Soft symbol waveform'],'Position',[890 160 920 180]);
for k=0:1
 fir=sprintf('Matched FIR %d',k);mag=sprintf('Magnitude %d',k);sq=sprintf('Energy %d',k);y=65+220*k;
 add_block('simulink/Discrete/Discrete FIR Filter',[p '/' fir], ...
  'Coefficients',sprintf('exp(1i*2*pi*cfg.f%d*(0:cfg.sps-1)/cfg.fs)/cfg.sps',k), ...
  'InputProcessing','Columns as channels (frame based)','Position',[170 y 295 y+45]);
 add_block('simulink/Math Operations/Abs',[p '/' mag],'Position',[360 y 410 y+45]);
 add_block('simulink/Math Operations/Math Function',[p '/' sq],'Operator','square','Position',[470 y 520 y+45]);
 wire(p,'Received complex samples/1',[fir '/1']);wire(p,[fir '/1'],[mag '/1']);wire(p,[mag '/1'],[sq '/1']);
end
add_block('simulink/Math Operations/Sum',[p '/E1 minus E0'],'Inputs','+-','Position',[640 95 670 135]);
add_block('simulink/Math Operations/Sum',[p '/Total energy plus floor'],'Inputs','+++','Position',[640 265 670 325]);
add_block('simulink/Sources/Constant',[p '/Floor'],'Value','1e-12','Position',[470 410 520 440]);
add_block('simulink/Math Operations/Divide',[p '/Normalize difference'],'Position',[770 145 820 195]);
wire(p,'Energy 1/1','E1 minus E0/1');wire(p,'Energy 0/1','E1 minus E0/2');
wire(p,'Energy 1/1','Total energy plus floor/1');wire(p,'Energy 0/1','Total energy plus floor/2');wire(p,'Floor/1','Total energy plus floor/3');
wire(p,'E1 minus E0/1','Normalize difference/1');wire(p,'Total energy plus floor/1','Normalize difference/2');
wire(p,'Normalize difference/1','Soft symbol waveform/1');
end

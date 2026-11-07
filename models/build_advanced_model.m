function build_advanced_model()
root=fileparts(fileparts(mfilename('fullpath')));
here=fullfile(root,'src','psk');
mdl='stuAdvancedSimulation';target=fullfile(here,[mdl '.slx']);
if bdIsLoaded(mdl),close_system(mdl,0);end
createLabModel(mdl);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','auto','ReturnWorkspaceOutputs','on','SaveOutput','off','SaveTime','off', ...
 'StopTime','(numel(txWave)-cfg.frameSamples)/cfg.fs');
src=sprintf('Signal From\nWorkspace');awgn=sprintf('AWGN\nChannel');fade='SISO Fading Channel1';iq=sprintf('Complex to\nReal-Imag');
set_param([mdl '/' src],'X','txWave','Ts','1/cfg.fs','nsamps','cfg.frameSamples','OutputAfterFinalValue','Setting to zero','Position',[30 180 130 220]);
for tuple={{'Q source','txQWave',[30 280 130 320]},{'Pulse gate','txGate',[30 380 130 420]}}
 t=tuple{1};add_block([mdl '/' src],[mdl '/' t{1}],'X',t{2},'Position',t{3});
end
addMod([mdl '/PSK and pulse shaping']);set_param([mdl '/PSK and pulse shaping'],'Position',[205 180 350 310],'ShowPortLabels','none');
wire(mdl,[src '/1'],'PSK and pulse shaping/1');wire(mdl,'Q source/1','PSK and pulse shaping/2');wire(mdl,'Pulse gate/1','PSK and pulse shaping/3');
set_param([mdl '/' awgn],'Position',[420 200 500 245],'LegacyMode','off','NoiseMethod','Signal to noise ratio  (Eb/No)', ...
 'EbNo','cfg.ebNo','BitsPerSymbol','cfg.bitsPerSymbol','SignalPower','1','SpecifySymbolPeriod','off', ...
 'SamplesPerSymbol','cfg.sps','RandomStream','mt19937ar with seed','Seed','cfg.awgnSeed','SimulateUsing','Interpreted execution');
set_param([mdl '/' fade],'Position',[565 185 690 265],'Seed','cfg.fadingSeed');
addDemod([mdl '/Downconversion and matched filter']);set_param([mdl '/Downconversion and matched filter'],'Position',[760 185 930 265],'ShowPortLabels','none');
set_param([mdl '/To Workspace1'],'VariableName','rxWave','SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf','Position',[1010 205 1120 245],'ShowName','on');
wire(mdl,'PSK and pulse shaping/1',[awgn '/1']);wire(mdl,[awgn '/1'],[fade '/1']);wire(mdl,[fade '/1'],'Downconversion and matched filter/1');wire(mdl,'Downconversion and matched filter/1','To Workspace1/1');
set_param([mdl '/' iq],'Position',[760 395 820 435]);wire(mdl,[fade '/1'],[iq '/1']);
set_param([mdl '/Scope'],'Position',[1020 390 1070 440],'NumInputPorts','2','OpenAtSimulationStart','off');wire(mdl,[iq '/1'],'Scope/1');wire(mdl,'Downconversion and matched filter/1','Scope/2');
spec=[mdl sprintf('/Spectrum\nAnalyzer')];set_param(spec,'Position',[430 390 500 435],'SampleRate','cfg.fs','ChannelNames',"{'PSK TX'}");sc=get_param(spec,'ScopeConfiguration');sc.OpenAtSimulationStart=false;
wire(mdl,'PSK and pulse shaping/1',sprintf('Spectrum\nAnalyzer/1'));
addLog(mdl,'Transmitted waveform','txSignal',[230 475 350 515],'PSK and pulse shaping/1');
addLog(mdl,'Noisy waveform','awgnSignal',[420 485 535 525],[awgn '/1']);
addLog(mdl,'Channel waveform','channelSignal',[565 395 690 435],[fade '/1']);
addLog(mdl,'Matched output','matchedSignal',[795 485 925 525],'Downconversion and matched filter/1');
note=Simulink.Annotation(mdl,'BPSK / QPSK: 48 ksample/s, 3 ksymbol/s, RRC pulse shaping');note.Position=[35 35];
set_param(mdl,'InitFcn','advInitModel;','StopFcn','advStopModel;','ReturnWorkspaceOutputs','off');
save_system(mdl,target);fprintf('BUILT_ADVANCED_MODEL %s\n',target);
end
function wire(mdl,a,b),add_line(mdl,a,b,'autorouting','on');end
function addLog(mdl,name,var,pos,source)
add_block('simulink/Sinks/To Workspace',[mdl '/' name],'VariableName',var,'SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf','Position',pos);wire(mdl,source,[name '/1']);
end
function addMod(p)
add_block('built-in/Subsystem',p);
for k=1:3,add_block('simulink/Ports & Subsystems/In1',[p sprintf('/Input %d',k)],'Port',num2str(k),'Position',[25 60+100*k 55 80+100*k]);end
for k=1:2
 add_block('simulink/Math Operations/Gain',[p sprintf('/Minus two %d',k)],'Gain','-2','Position',[110 55+100*k 155 85+100*k]);
 add_block('simulink/Math Operations/Bias',[p sprintf('/Add one %d',k)],'Bias','1','Position',[200 55+100*k 245 85+100*k]);
 wire(p,sprintf('Input %d/1',k),sprintf('Minus two %d/1',k));wire(p,sprintf('Minus two %d/1',k),sprintf('Add one %d/1',k));
end
add_block('simulink/Math Operations/Gain',[p '/Q enabled'],'Gain','cfg.qGain','Position',[290 255 330 285]);wire(p,'Add one 2/1','Q enabled/1');
add_block('simulink/Math Operations/Real-Imag to Complex',[p '/I plus jQ'],'Position',[385 175 445 255]);wire(p,'Add one 1/1','I plus jQ/1');wire(p,'Q enabled/1','I plus jQ/2');
add_block('simulink/Math Operations/Gain',[p '/Unit symbol energy'],'Gain','cfg.symbolScale','Position',[490 185 540 235]);wire(p,'I plus jQ/1','Unit symbol energy/1');
add_block('simulink/Math Operations/Product',[p '/Upsampled impulses'],'Position',[610 200 655 245]);wire(p,'Unit symbol energy/1','Upsampled impulses/1');wire(p,'Input 3/1','Upsampled impulses/2');
add_block('simulink/Discrete/Discrete FIR Filter',[p '/Transmit pulse filter'],'Coefficients','cfg.txFilter','InputProcessing','Columns as channels (frame based)','Position',[715 195 845 250]);wire(p,'Upsampled impulses/1','Transmit pulse filter/1');
add_block('dspsrcs4/Sine Wave',[p '/TX complex carrier'],'Amplitude','1','Frequency','cfg.fc+cfg.frequencyOffsetHz','Phase','cfg.phaseOffsetRad','OutComplex','Complex','SampleTime','1/cfg.fs','SamplesPerFrame','cfg.frameSamples','Position',[715 330 845 380]);
add_block('simulink/Math Operations/Product',[p '/Quadrature modulation'],'Position',[920 200 965 245]);wire(p,'Transmit pulse filter/1','Quadrature modulation/1');wire(p,'TX complex carrier/1','Quadrature modulation/2');
add_block('simulink/Ports & Subsystems/Out1',[p '/PSK output'],'Position',[1030 212 1060 232]);wire(p,'Quadrature modulation/1','PSK output/1');
end
function addDemod(p)
add_block('built-in/Subsystem',p);add_block('simulink/Ports & Subsystems/In1',[p '/Channel input'],'Position',[30 105 60 125]);
add_block('dspsrcs4/Sine Wave',[p '/RX nominal carrier'],'Amplitude','1','Frequency','cfg.fc','Phase','0','OutComplex','Complex','SampleTime','1/cfg.fs','SamplesPerFrame','cfg.frameSamples','Position',[100 235 245 285]);
add_block('simulink/Math Operations/Math Function',[p '/Conjugate LO'],'Operator','conj','Position',[295 235 350 285]);wire(p,'RX nominal carrier/1','Conjugate LO/1');
add_block('simulink/Math Operations/Product',[p '/Complex downconverter'],'Position',[405 95 455 145]);wire(p,'Channel input/1','Complex downconverter/1');wire(p,'Conjugate LO/1','Complex downconverter/2');
add_block('simulink/Discrete/Discrete FIR Filter',[p '/Receive matched pulse'],'Coefficients','cfg.rxFilter','InputProcessing','Columns as channels (frame based)','Position',[520 95 660 145]);wire(p,'Complex downconverter/1','Receive matched pulse/1');
add_block('simulink/Ports & Subsystems/Out1',[p '/Matched complex waveform'],'Position',[740 110 770 130]);wire(p,'Receive matched pulse/1','Matched complex waveform/1');
end

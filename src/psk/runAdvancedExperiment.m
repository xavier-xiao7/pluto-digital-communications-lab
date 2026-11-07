function [out,rx,cfg,truth]=runAdvancedExperiment(payload,options)
% Teacher-derived PSK chain, actual Simulink graph, receiver-only acquisition.
if nargin<1,payload='Lab advanced communication experiment: BPSK/QPSK, RRC and FEC.';end
if nargin<2,options=struct();end
here=fileparts(mfilename('fullpath'));oldpath=path;guard=onCleanup(@()path(oldpath));addpath(here,'-begin');
cfg=advExperimentConfig(options);
[txWave,txQWave,txGate,truth]=advPrepareExperiment(payload,cfg);
mdl='stuAdvancedSimulation';full=fullfile(here,[mdl '.slx']);
if bdIsLoaded(mdl),assert(strcmpi(get_param(mdl,'FileName'),full),'Different advanced model already loaded.');end
load_system(full);in=Simulink.SimulationInput(mdl);
in=in.setVariable('cfg',cfg).setVariable('txWave',txWave).setVariable('txQWave',txQWave).setVariable('txGate',txGate);
noise='off';fading='off';if ismember(cfg.channelMode,{'ideal','rician'}),noise='through';end
if ismember(cfg.channelMode,{'ideal','awgn'}),fading='through';end
in=in.setBlockParameter([mdl sprintf('/AWGN\nChannel')],'Commented',noise);
in=in.setBlockParameter([mdl '/SISO Fading Channel1'],'Commented',fading);
in=in.setModelParameter('StopTime',num2str((numel(txWave)-cfg.frameSamples)/cfg.fs,16), ...
 'ReturnWorkspaceOutputs','on','InitFcn','','StopFcn','');
rxCfg=advPskConfig(cfg.modulation);
in=in.setPostSimFcn(@(o)advPostSimulation(o,rxCfg));
out=sim(in);rx=out.advancedRx;
fprintf('%s %s EbNo=%g: complete=%d frames=%d bytes=%d\n',cfg.modulation,cfg.channelMode,cfg.ebNo,rx.complete,rx.validFrameCount,numel(rx.bytes));
end

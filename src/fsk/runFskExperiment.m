function [out,rxResult,cfg,txTruth]=runFskExperiment(msg,options)
% Run the 2FSK Simulink chain; never opens a window or uses RF.
% options can be a cfg structure or scalar Eb/N0 in dB.
if nargin<1,msg='Hello, world! Lab 2FSK communication experiment 2026.';end
here=fileparts(mfilename('fullpath'));oldpath=path;cleanup=onCleanup(@()path(oldpath));addpath(here,'-begin');
cfg=fskConfig();
if nargin>=2
 if isstruct(options)
  fields=fieldnames(options);for k=1:numel(fields),cfg.(fields{k})=options.(fields{k});end
 else,validateattributes(options,{'numeric'},{'scalar','real','finite'});cfg.ebNo=options;
 end
end
if ~isfield(cfg,'frequencyOffsetHz'),cfg.frequencyOffsetHz=0;end
if ~isfield(cfg,'phaseOffsetRad'),cfg.phaseOffsetRad=0;end
assert(ismember(cfg.channelMode,{'ideal','awgn','rician','combined'}),'Unknown channelMode.');
assert(cfg.signalPower==1,'This model uses unit-power complex tones; signalPower must be 1.');
assert(cfg.f0>0&&cfg.f1<cfg.fs/2&&cfg.f1>cfg.f0,'Invalid 2FSK frequencies.');
assert(abs((cfg.f1-cfg.f0)/cfg.baud-round((cfg.f1-cfg.f0)/cfg.baud))<1e-12,'FSK tones must be orthogonal over one symbol.');
run(fullfile(here,'stuTextToWave.m'));
mdl='stuFskSimulation';modelPath=fullfile(here,[mdl '.slx']);
if bdIsLoaded(mdl),assert(strcmpi(get_param(mdl,'FileName'),modelPath),'A different FSK model with this name is loaded.');end
load_system(modelPath);
in=Simulink.SimulationInput(mdl);in=in.setVariable('cfg',cfg).setVariable('txWave',txWave);
awgnState='off';fadingState='off';
if ismember(cfg.channelMode,{'ideal','rician'}),awgnState='through';end
if ismember(cfg.channelMode,{'ideal','awgn'}),fadingState='through';end
in=in.setBlockParameter([mdl sprintf('/AWGN\nChannel')],'Commented',awgnState);
in=in.setBlockParameter([mdl '/SISO Fading Channel1'],'Commented',fadingState);
in=in.setModelParameter('StopTime',num2str((numel(txWave)-cfg.frameSamples)/cfg.fs,16), ...
    'InitFcn','','StopFcn','','ReturnWorkspaceOutputs','on');
out=sim(in);
run(fullfile(here,'stuWaveToText.m'));
end

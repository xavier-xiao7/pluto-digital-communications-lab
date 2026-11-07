function advInitModel()
% Model Run-button callback. Uses explicit user inputs or a fresh default.
if evalin('base','exist(''msg'',''var'')'),payload=evalin('base','msg');
else,payload='Lab model Run button: automatic source and receiver.';end
if evalin('base','exist(''advOptions'',''var'')'),options=evalin('base','advOptions');else,options=struct();end
cfg=advExperimentConfig(options);[txWave,txQWave,txGate,txTruth]=advPrepareExperiment(payload,cfg);
assignin('base','cfg',cfg);assignin('base','txWave',txWave);assignin('base','txQWave',txQWave);assignin('base','txGate',txGate);assignin('base','txTruth',txTruth);
evalin('base','clear rxWave advancedLastResult');
mdl='stuAdvancedSimulation';noise='off';fading='off';
if ismember(cfg.channelMode,{'ideal','rician'}),noise='through';end
if ismember(cfg.channelMode,{'ideal','awgn'}),fading='through';end
set_param([mdl sprintf('/AWGN\nChannel')],'Commented',noise);
set_param([mdl '/SISO Fading Channel1'],'Commented',fading);
end

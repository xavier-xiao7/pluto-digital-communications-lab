%% Teacher source script extended to general byte payloads
if ~exist('msg','var'), msg='Lab advanced BPSK and QPSK experiment.'; end
if ~exist('advOptions','var'), advOptions=struct(); end
cfg=advExperimentConfig(advOptions);
[txWave,txQWave,txGate,txTruth]=advPrepareExperiment(msg,cfg);
advApplyChannelMode(cfg);
% Run manually as:
% out=sim('stuAdvancedSimulation','ReturnWorkspaceOutputs','on','InitFcn','','StopFcn','');

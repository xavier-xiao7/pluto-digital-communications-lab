function advApplyChannelMode(cfg)
% Apply manual/GUI channel selection explicitly; do not inherit old bypasses.
mdl='stuAdvancedSimulation';file=fullfile(fileparts(mfilename('fullpath')),[mdl '.slx']);
if bdIsLoaded(mdl),assert(strcmpi(get_param(mdl,'FileName'),file),'Different advanced model already loaded.');end
load_system(file);noise='off';fading='off';
if ismember(cfg.channelMode,{'ideal','rician'}),noise='through';end
if ismember(cfg.channelMode,{'ideal','awgn'}),fading='through';end
set_param([mdl sprintf('/AWGN\nChannel')],'Commented',noise);
set_param([mdl '/SISO Fading Channel1'],'Commented',fading);
end

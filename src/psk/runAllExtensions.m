function summary=runAllExtensions(destination)
% Reproduce the component checks and the teacher-derived full-link tests.
here=fileparts(mfilename('fullpath'));oldpath=path;cleanup=onCleanup(@()path(oldpath));
addpath(here,fullfile(here,'tests'),'-begin');
if nargin<1,destination=fullfile(fileparts(here),'复验输出');end
if ~isfolder(destination),mkdir(destination);end
summary=struct('matlab',version,'physicalRadioTested',false,'physicalSoundcardTested',false);
summary.protocol=verifyProtocol;writeJson(fullfile(destination,'protocol_tests.json'),summary.protocol);
summary.portable=verifyAdvancedPortable;writeJson(fullfile(destination,'portable_tests.json'),summary.portable);
summary.psk=verifyPskReceiver;writeJson(fullfile(destination,'psk_receiver_tests.json'),summary.psk);
summary.pskChallenges=verifyPskChallenges(fullfile(destination,'psk_challenges.json'));
summary.coding=validateCodingExtensions(fullfile(destination,'coding'));
summary.soundcard=validateSoundcardOffline(fullfile(destination,'soundcard'));
summary.fullLink=validateAdvancedExperiment(fullfile(destination,'advanced'));
summary.figures=createAdvancedFigures(fullfile(destination,'figures'),fullfile(destination,'advanced','advanced_snapshots.mat'));
summary.completed=true;writeJson(fullfile(destination,'all_extensions_summary.json'),summary);
fprintf('ALL_EXTENSION_SOFTWARE_CHECKS_COMPLETED\n');
end
function writeJson(file,data)
fid=fopen(file,'w','n','UTF-8');guard=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(data,PrettyPrint=true),'char');
end

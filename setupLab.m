function root=setupLab(rebuild)
% Set paths, keep generated files local, and build the two Simulink models.
if nargin<1,rebuild=false;end
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'models'),fullfile(root,'tests'), ...
 fullfile(root,'src','fsk'),fullfile(root,'src','psk'), ...
 fullfile(root,'src','psk','tests'),fullfile(root,'src','ui'), ...
 fullfile(root,'src','hardware'),fullfile(root,'src','hardware','demo'));
Simulink.fileGenControl('set','CacheFolder',fullfile(root,'results','cache'), ...
 'CodeGenFolder',fullfile(root,'results','codegen'),'createDir',true);
if rebuild||~isfile(fullfile(root,'src','fsk','stuFskSimulation.slx')),build_fsk_model();end
if rebuild||~isfile(fullfile(root,'src','psk','stuAdvancedSimulation.slx')),build_advanced_model();end
sampleDir=fullfile(root,'src','hardware','demo','test_images');
if ~isfile(fullfile(sampleDir,'01_test_A.png'))
 if ~isfolder(sampleDir),mkdir(sampleDir);end
 [x,y]=meshgrid(0:31,0:31);
 pattern=cat(3,uint8(8*x),uint8(8*y),uint8(255*mod(floor(x/4)+floor(y/4),2)));
 imwrite(pattern,fullfile(sampleDir,'01_test_A.png'));
end
fprintf('Lab ready. Run commLabLauncher or runPublicChecks.\n');
end

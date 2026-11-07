function result=runFullMatrices(destination)
% Complete-link channel matrices; RF and audio hardware are not accessed.
root=setupLab();
if nargin<1
 destination=fullfile(root,'results','matrices',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
end
if ~isfolder(destination),mkdir(destination);end
result.advanced=validateAdvancedExperiment(fullfile(destination,'psk'));
result.fsk=validateFskExperiment(fullfile(destination,'fsk'));
fid=fopen(fullfile(destination,'matrices.json'),'w','n','UTF-8');
guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));
fprintf('PUBLIC_FULL_MATRICES_PASS\n');
end

function summary=runPublicChecks(destination)
% Software-only release checks: no SDR device or soundcard is opened.
root=setupLab();
if nargin<1
 destination=fullfile(root,'results','checks',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
end
assert(~isfile(fullfile(destination,'checks.json')),'Choose a fresh result directory.');
if ~isfolder(destination),mkdir(destination);end
summary=struct('matlab',version,'radioAccessed',false,'audioHardwareAccessed',false);
summary.protocol=verifyProtocol();
summary.portable=verifyAdvancedPortable();
summary.pskReceiver=verifyPskReceiver();
summary.pskChallenges=verifyPskChallenges(fullfile(destination,'psk_challenges.json'));
summary.demos=runCommLabDemos(root,fullfile(destination,'demos'), ...
 @(i,n,name,state,detail)fprintf('%d/%d %s: %s %s\n',i,n,name,state,detail));
assert(summary.demos.allPassed,'Public demonstration regression failed.');
summary.hardwareFsk=verifyPlutoFskOffline(fullfile(destination,'hardware_fsk'));
summary.hardwarePsk=verifyRadioWaveforms();
% Construct both actual UI classes without exposing or transmitting RF.
app=commLabLauncher('Visible',false,'AutoRun',false,'OpenModels',false);
labels=findall(app.Window,'Type','uibutton');
assert(numel(labels)==4,'Unexpected simulation UI buttons.');
delete(app.Window);
terminal=PlutoTerminal('RX','off',true);
assert(terminal.Preview&&strcmp(terminal.Buttons(1).Enable,'off'));
delete(terminal.Figure);
summary.uiConstructed=true;summary.passed=true;
fid=fopen(fullfile(destination,'checks.json'),'w','n','UTF-8');
guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true));
fprintf('PUBLIC_RELEASE_CHECKS_PASS\n');
end

function rows=verifyRadioWaveforms()
% Only the synthesized IQ and public modulation choice enter the decoder.
demoInit();payload=unicode2native('Public radio waveform / 无线测试','UTF-8').';
rows=struct('mode',{},'passed',{},'bytes',{},'cfoHz',{},'bufferSeconds',{});
for item={'BPSK','QPSK'}
 mode=item{1};[iq,meta]=demoMakeWave(payload,mode);
 n=(0:numel(iq)-1).';iq=double(iq).*exp(1i*(2*pi*18000*n/1e6+0.7));
 received=demoDecode(iq,mode);
 assert(received.complete&&isequal(received.bytes,payload),'Radio waveform byte mismatch.');
 rows(end+1)=struct('mode',mode,'passed',true,'bytes',numel(payload), ...
  'cfoHz',received.cfoHz,'bufferSeconds',meta.bufferSeconds); %#ok<AGROW>
 fprintf('%s radio waveform: decoded %d bytes from software-generated IQ.\n',mode,numel(payload));
end
end

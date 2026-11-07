function report=plutoFskTransmit(centerHz,radioID,message,durationSeconds,outputDir,changes)
% Explicit finite RF transmission. Calling this function DOES transmit.
% Frequency and device identity have no implicit defaults.
validateattributes(centerHz,{'numeric'},{'scalar','finite','>=',325e6,'<=',3.8e9});
assert(ischar(radioID)||(isstring(radioID)&&isscalar(radioID)));
assert(~isempty(regexp(char(radioID),'^(usb:|ip:|sn:).+','once')),'PLUTO:RadioID','Explicit radio identity required.');
validateattributes(durationSeconds,{'numeric'},{'scalar','finite','>=',1,'<=',30});
if nargin<6,changes=struct();end
options=plutoFskOptions(changes);
assert(isfolder(outputDir)||mkdir(outputDir));
assert(~isfile(fullfile(outputDir,'tx_result.json')),'PLUTO:ExistingOutput','Choose a fresh output folder.');
assert(exist('sdrtx','file')>0,'PLUTO:SupportPackage','Pluto support package is unavailable.');
[wave,metadata]=plutoFskMakeWave(message,options);
report=struct('state','Prepared','computer',getenv('COMPUTERNAME'),'centerFrequencyHz',centerHz, ...
    'radioID',char(radioID),'sampleRate',options.radioSampleRate,'digitalIfHz',options.digitalIfHz,'gainDb',options.txGainDb, ...
    'requestedSeconds',durationSeconds,'waveform',metadata,'scheduledStartUtc',options.startAtUtc, ...
    'transmissionStartedUtc','','transmissionStoppedUtc','','released',false,'error','');
plutoFskWriteJson(fullfile(outputDir,'tx_result.json'),report);
plutoFskWaitUntil(options.startAtUtc);
tx=sdrtx('Pluto','RadioID',char(radioID),'CenterFrequency',centerHz, ...
    'BasebandSampleRate',options.radioSampleRate,'Gain',options.txGainDb);
releaseGuard=onCleanup(@()release(tx));
try
    started=tic;transmitRepeat(tx,wave);
    report.transmissionStartedUtc=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
    report.state='Transmitting';plutoFskWriteJson(fullfile(outputDir,'tx_result.json'),report);
    while toc(started)<durationSeconds,pause(min(0.1,max(0.001,durationSeconds-toc(started))));end
    release(tx);clear releaseGuard
    report.released=true;report.state='Finished';report.elapsedSeconds=toc(started);
    report.transmissionStoppedUtc=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
    plutoFskWriteJson(fullfile(outputDir,'tx_result.json'),report);
catch exception
    release(tx);clear releaseGuard
    report.released=true;report.state='Failed';report.error=getReport(exception,'extended','hyperlinks','off');
    report.transmissionStoppedUtc=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
    plutoFskWriteJson(fullfile(outputDir,'tx_result.json'),report);rethrow(exception);
end
end

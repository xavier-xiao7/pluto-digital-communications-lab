function [result,report]=plutoFskReceive(centerHz,radioID,captureSeconds,outputDir,changes)
% Finite physical RX capture; no transmitter payload or truth enters decoding.
validateattributes(centerHz,{'numeric'},{'scalar','finite','>=',325e6,'<=',3.8e9});
assert(ischar(radioID)||(isstring(radioID)&&isscalar(radioID)));
assert(~isempty(regexp(char(radioID),'^(usb:|ip:|sn:).+','once')),'PLUTO:RadioID','Explicit radio identity required.');
if nargin<5,changes=struct();end
options=plutoFskOptions(changes);
validateattributes(captureSeconds,{'numeric'},{'scalar','finite','>=',1,'<=',options.maxCaptureSeconds});
assert(isfolder(outputDir)||mkdir(outputDir));
assert(~isfile(fullfile(outputDir,'rx_result.json')),'PLUTO:ExistingOutput','Choose a fresh output folder.');
assert(exist('sdrrx','file')>0,'PLUTO:SupportPackage','Pluto support package is unavailable.');
frameCount=ceil(captureSeconds*options.radioSampleRate/options.samplesPerFrame);
report=struct('state','Prepared','computer',getenv('COMPUTERNAME'),'centerFrequencyHz',centerHz, ...
    'radioID',char(radioID),'sampleRate',options.radioSampleRate,'digitalIfHz',options.digitalIfHz,'gainDb',options.rxGainDb, ...
    'requestedSeconds',captureSeconds,'samplesPerFrame',options.samplesPerFrame, ...
    'frameCount',frameCount,'scheduledStartUtc',options.startAtUtc,'startedUtc','','finishedUtc','', ...
    'overflowCount',0,'invalidFrameCount',0,'complete',false,'message','','error','');
plutoFskWriteJson(fullfile(outputDir,'rx_result.json'),report);
plutoFskWaitUntil(options.startAtUtc);
rx=sdrrx('Pluto','RadioID',char(radioID),'CenterFrequency',centerHz, ...
    'BasebandSampleRate',options.radioSampleRate,'GainSource','Manual','Gain',options.rxGainDb, ...
    'OutputDataType','single','SamplesPerFrame',options.samplesPerFrame, ...
    'EnableBurstMode',true,'NumFramesInBurst',frameCount+2);
releaseGuard=onCleanup(@()release(rx));
iq=complex(zeros(options.samplesPerFrame,frameCount,'single'));
valid=false(frameCount,1);overflow=false(frameCount,1);completedFrames=0;
try
    started=tic;report.state='Capturing';
    report.startedUtc=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
    plutoFskWriteJson(fullfile(outputDir,'rx_result.json'),report);
    % Discard the documented first-call transients, before the recorded capture.
    [~,~,~]=rx();[~,~,~]=rx();
    for k=1:frameCount
        assert(toc(started)<captureSeconds+30,'PLUTO:CaptureDeadline','Capture exceeded its wall-clock budget.');
        [data,valid(k),overflow(k)]=rx();iq(:,k)=data;completedFrames=k;
    end
    release(rx);clear releaseGuard
    report.elapsedSeconds=toc(started);report.overflowCount=sum(overflow);report.invalidFrameCount=sum(~valid);
    report.capturedSamples=completedFrames*options.samplesPerFrame;
    [bounds,usable]=plutoFskContinuousSegments(valid,overflow);
    report.dataValidSeconds=sum(valid)*options.samplesPerFrame/options.radioSampleRate;
    report.usableSampleSeconds=sum(usable)*options.samplesPerFrame/options.radioSampleRate;
    save(fullfile(outputDir,'received_iq.mat'),'iq','valid','overflow','usable','report','options','-v7.3');
    % Discard an entire overflow frame; it may itself contain a sample gap.
    segments=struct('firstFrame',{},'lastFrame',{},'complete',{},'message',{},'diagnostics',{});
    result=[];
    for j=1:size(bounds,1)
        first=bounds(j,1);last=bounds(j,2);
        [decoded,diag]=plutoFskDecodeIq(reshape(iq(:,first:last),[],1),options);
        segments(end+1)=struct('firstFrame',first,'lastFrame',last,'complete',decoded.complete, ...
            'message',decoded.message,'diagnostics',diag); %#ok<AGROW>
        if isempty(result)||(~result.complete&&decoded.complete),result=decoded;end
    end
    if isempty(result),[result,~]=plutoFskDecodeIq(complex(zeros(4096,1)),options);end
    report.segments=segments;report.complete=result.complete;report.message=result.message;
    report.validFrameCopies=result.validFrameCount;report.state='Finished';
    report.wireComplete=false;report.transportCrcPassed=false;report.textDecoded=false;report.textDecodeError='';
    if isfield(result,'wireComplete'),report.wireComplete=result.wireComplete;report.transportCrcPassed=result.wireComplete;end
    if isfield(result,'textDecoded'),report.textDecoded=result.textDecoded;end
    if isfield(result,'textDecodeError'),report.textDecodeError=result.textDecodeError;end
    if isfield(result,'transport'),report.transport=result.transport;end
    report.finishedUtc=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
    save(fullfile(outputDir,'decoded_result.mat'),'result','report','-v7');
    if result.complete
        fid=fopen(fullfile(outputDir,'received_text.txt'),'w','n','UTF-8');guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',result.message);clear guard
    end
    plutoFskWriteJson(fullfile(outputDir,'rx_result.json'),report);
catch exception
    release(rx);clear releaseGuard
    report.state='Failed';report.error=getReport(exception,'extended','hyperlinks','off');
    report.finishedUtc=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
    save(fullfile(outputDir,'received_iq_partial.mat'),'iq','valid','overflow','completedFrames','report','-v7.3');
    plutoFskWriteJson(fullfile(outputDir,'rx_result.json'),report);rethrow(exception);
end
end

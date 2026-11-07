function summary=verifyPlutoFskOffline(outputDir)
% Software-only bridge checks. No SDR functions are called by this test.
here=fileparts(mfilename('fullpath'));
if nargin<1,outputDir=fullfile(here,'离线验证');end
assert(isfolder(outputDir)||mkdir(outputDir));
oldPath=path;guard=onCleanup(@()path(oldPath));addpath(here,fullfile(here,'fskCore'),'-begin');
rng(20261029,'twister');options=plutoFskOptions();
message='FSK hardware bridge: frame one plus frame two. Public baseline. CRC checks both fragments.';
[wave,metadata]=plutoFskMakeWave(message,options);
assert(metadata.frameCount==2&&metadata.radioSamples==10*metadata.sourceSamples);
assert(metadata.peakAmplitude<=options.txAmplitude+1e-6);
summary=struct('kind','OFFLINE ONLY; no radio access','createdUtc',utcNow(), ...
    'waveform',metadata,'results',struct([]),'passed',false);
runCase('clean_two_fragment',wave,true,message,0);
delayed=[complex(zeros(7131,1,'single'));0.23*wave*exp(1i*1.73);complex(zeros(10007,1,'single'))];
runCase('unknown_delay_phase_and_gain',addNoise(delayed,23),true,message,0);
runCase('cfo_plus_50k_clock_plus_1000ppm',impair(wave,50000,1000),true,message,50000);
runCase('cfo_minus_50k_clock_minus_1000ppm',impair(wave,-50000,-1000),true,message,-50000);
runCase('cfo_minus_8k',impair(wave,-8000,0),true,message,-8000);
runCase('cfo_minus_12k',impair(wave,-12000,0),true,message,-12000);
runCase('cfo_minus_7900_strong_dc',impair(wave,-7900,0)+0.3+0.1i,true,message,-7900);
runCase('cfo_minus_12100_strong_dc',impair(wave,-12100,0)+0.3+0.1i,true,message,-12100);
% The capture begins at an arbitrary position of a cyclic playback buffer.
cyclic=repmat(wave,2,1);cut=431173;cyclic=cyclic(cut:end-123457);
runCase('cyclic_arbitrary_capture_start',addNoise(cyclic*exp(-1i*0.6),20),true,message,0);
runCase('silence_rejected',complex(zeros(700000,1,'single')),false,'',NaN);
noise=complex(randn(900000,1,'single'),randn(900000,1,'single'))*0.08;
runCase('noise_rejected',noise,false,'',NaN);
n=(0:899999).';spur=0.18+0.1*exp(1i*2*pi*31000*n/1e6);
runCase('dc_plus_single_tone_rejected',addNoise(spur,35),false,'',NaN);
% Corrupt a protected payload bit in every copy, without updating either CRC.
cfg=fskConfig();[bits,truth]=fskEncodeText(message,cfg);
for j=1:numel(truth.frameBitStarts)
    bitIndex=truth.frameBitStarts(j)+numel(cfg.preamble)+numel(cfg.sync)+cfg.headerBytes*8+17;
    first=cfg.leadSamples+(bitIndex-1)*cfg.sps+1;
    bits(first:first+cfg.sps-1)=1-bits(first:first+cfg.sps-1);
end
n=(0:numel(bits)-1).';base=(1-bits).*exp(1i*2*pi*cfg.f0*n/cfg.fs)+bits.*exp(1i*2*pi*cfg.f1*n/cfg.fs);
corrupt=resample(base,10,1,32,8.6);n=(0:numel(corrupt)-1).';
corrupt=corrupt.*exp(1i*2*pi*options.digitalIfHz*n/options.radioSampleRate);
corrupt=corrupt*0.25/max(abs(corrupt));
runCase('payload_corrupted_all_copies_rejected',corrupt,false,'',0);
summary.segmentHandling=verifySegments();
summary.passed=all([summary.results.passed])&&summary.segmentHandling.passed;summary.finishedUtc=utcNow();
plutoFskWriteJson(fullfile(outputDir,'offline_summary.json'),summary);
save(fullfile(outputDir,'offline_summary.mat'),'summary','-v7');
assert(summary.passed,'PLUTO:OfflineRegression','One or more offline checks failed. See offline_summary.json.');
fprintf('PLUTO FSK OFFLINE PASS: %d/%d waveform cases plus overflow-segment check; no RF transmission.\n',sum([summary.results.passed]),numel(summary.results));

    function runCase(name,input,expectedComplete,expectedMessage,expectedCfo)
        timer=tic;[result,diagnostics]=plutoFskDecodeIq(input,options);
        passed=(result.complete==expectedComplete);
        if expectedComplete,passed=passed&&strcmp(result.message,expectedMessage);end
        if expectedComplete&&isfinite(expectedCfo),passed=passed&&abs(diagnostics.coarseCfoHz-expectedCfo)<150;end
        row=struct('name',name,'passed',passed,'expectedComplete',expectedComplete, ...
            'complete',result.complete,'message',result.message,'validFrameCopies',result.validFrameCount, ...
            'expectedCfoHz',expectedCfo,'diagnostics',diagnostics,'seconds',toc(timer));
        summary.results=[summary.results;row];
        plutoFskWriteJson(fullfile(outputDir,'offline_summary.json'),summary);
        fprintf('%s: passed=%d complete=%d copies=%d CFO=%0.2f Hz\n',name,passed,result.complete,result.validFrameCount,diagnostics.coarseCfoHz);
    end
end

function check=verifySegments()
% Sample tags make an accidentally retained overflow block or joined gap visible.
valid=[true true true true false true true true];
overflow=[false true false false false false true false];
[bounds,usable]=plutoFskContinuousSegments(valid,overflow);
tagged=repelem(1:8,4).';data=reshape(tagged,4,8);actual=cell(size(bounds,1),1);
for j=1:size(bounds,1),actual{j}=reshape(data(:,bounds(j,1):bounds(j,2)),[],1).';end
expected={ones(1,4);[repmat(3,1,4),repmat(4,1,4)];repmat(6,1,4);repmat(8,1,4)};
[edgeBounds,edgeUsable]=plutoFskContinuousSegments([true true true],[true false true]);
passed=isequal(bounds,[1 1;3 4;6 6;8 8])&&isequal(actual,expected)&& ...
    ~any(usable([2 5 7]))&&isequal(edgeBounds,[2 2])&&isequal(edgeUsable,[false;true;false]);
check=struct('name','entire_overflow_frame_discarded_and_gap_not_joined','passed',passed, ...
    'bounds',bounds,'usableFrames',find(usable).','decodedSegmentSampleTags',{actual});
fprintf('overflow_segment_handling: passed=%d\n',passed);
end

function y=impair(x,cfo,clockPpm)
% Independently alter sampling clock; receiver receives none of these values.
x=double(x(:));query=(0:1/(1+clockPpm*1e-6):numel(x)-1).';
y=interp1((0:numel(x)-1).',x,query,'linear');
y=[complex(zeros(12379,1));y;complex(zeros(8711,1))];
n=(0:numel(y)-1).';y=0.41*y.*exp(1i*(2*pi*cfo*n/1e6+2.4));y=addNoise(y,22);
end
function y=addNoise(x,snrDb)
power=mean(abs(x).^2);scale=sqrt(power/10^(snrDb/10)/2);
y=x+scale*complex(randn(size(x)),randn(size(x)));
end
function value=utcNow()
value=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

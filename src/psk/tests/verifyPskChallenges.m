function results=verifyPskChallenges(outputPath)
% Additional independent baseband challenge. Actual SLX runs are separate.
% Teacher channel order is kept: AWGN before normalized single-path Rician.
if nargin<1,outputPath=fullfile(fileparts(mfilename('fullpath')),'psk_challenges.json');end
specs={ ...
    'BPSK',25, 131, -250,  1.77, 47, 0,     true; ...
    'QPSK',25, 149,  250, -2.84, 91, 0,     true; ...
    'BPSK',25, 167,  183, -0.98, 13, 1500,  true; ...
    'QPSK',25, 181, -183,  2.98, 61,-1500,  true; ...
    'BPSK',25, 197,  -39,  0.53, 29, 0,     true; ...
    'QPSK',25, 211,   39, -1.53, 37, 0,     true; ...
    'BPSK', 0, 227,  117,  1.1,  19, 0,     false; ...
    'QPSK', 0, 239, -117, -1.1,  43, 0,     false; ...
    'BPSK',25, 251,  700,  2.2,  31, 0,     false; ...
    'QPSK',25, 269, -700, -2.2,  53, 0,     false};
results=struct([]);
for k=1:size(specs,1)
    cfg=advPskConfig(specs{k,1}); rng(specs{k,3},'twister');
    bytes=uint8(randi([0 255],384+13*k,1)); pcfg=advProtocolConfig();
    pcfg.repetitions=2;
    if ismember(k,[5 6]),pcfg.lineCode='Manchester';end
    [~,truth]=advEncodeBytes(bytes,pcfg);
    [ib,qb,active,meta]=advPskFrameBits(truth.frames,cfg);
    symbols=((1-2*ib)+1i*cfg.qGain*(1-2*qb))*cfg.symbolNormalization.*active;
    impulses=complex(zeros(numel(symbols)*cfg.sps,1));
    impulses(1:cfg.sps:end)=symbols;
    h=rcosdesign(cfg.rolloff,cfg.filterSpan,cfg.sps,'sqrt').';
    tx=conv(impulses,sqrt(cfg.sps)*h);
    t=(0:numel(tx)-1).'/cfg.Fs;
    channelIn=tx.*exp(1i*(2*pi*specs{k,4}*t+specs{k,5}));
    variance=cfg.sps/cfg.bitsPerSymbol*10^(-specs{k,2}/10);
    channelIn=channelIn+sqrt(variance/2)*(randn(size(tx))+1i*randn(size(tx)));
    channel=comm.RicianChannel('SampleRate',cfg.Fs,'PathDelays',0.001, ...
        'AveragePathGains',-20,'NormalizePathGains',true,'KFactor',3, ...
        'MaximumDopplerShift',2,'DirectPathDopplerShift',1, ...
        'DirectPathInitialPhase',1,'RandomStream','mt19937ar with seed', ...
        'Seed',specs{k,3}+1);
    rx=channel(channelIn);release(channel);
    rx=conv(rx,h/sqrt(cfg.sps));
    if specs{k,7}~=0
        idx=(1:(1+specs{k,7}*1e-6):numel(rx)).';
        rx=interp1((1:numel(rx)).',rx,idx,'linear');
    end
    rx=[zeros(specs{k,6},1);rx;zeros(2*cfg.filterSpan*cfg.sps,1)];
    r=advReceivePsk(rx,cfg);
    recovered=r.complete&&isequal(r.bytes,bytes);
    results(k).modulation=cfg.modulation;results(k).ebNo=specs{k,2}; %#ok<AGROW>
    results(k).seed=specs{k,3};results(k).frequencyOffsetHz=specs{k,4};
    results(k).phaseOffsetRad=specs{k,5};results(k).extraDelaySamples=specs{k,6};
    results(k).clockPpm=specs{k,7};results(k).requiredPass=specs{k,8};
    results(k).payloadBytes=numel(bytes);results(k).lineCode=pcfg.lineCode;
    results(k).recovered=recovered;results(k).validFrameCount=r.validFrameCount;
    results(k).expectedTiles=meta.tileCount;results(k).detectedTiles=numel(r.tiles);
    results(k).coarseCfoHz=r.coarseCfoHz;results(k).estimatedClockPpm=r.estimatedClockPpm;
    fprintf('Independent Rician %d/%d %s EbNo=%g CFO=%g: recovered=%d tiles=%d/%d\n', ...
        k,size(specs,1),cfg.modulation,specs{k,2},specs{k,4},recovered,numel(r.tiles),meta.tileCount);
end
fid=fopen(outputPath,'w');assert(fid>=0);guard=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(results,'PrettyPrint',true));clear guard
required=[results.requiredPass];
assert(all([results(required).recovered]),'PSK:RicianBaseline', ...
    'One or more declared high-SNR Rician baselines did not recover. See saved JSON.');
end

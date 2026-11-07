function results=verifyFskReceiver()
% Receiver/protocol checks. Run centrally in a background MATLAB process.
here=fileparts(mfilename('fullpath'));
addpath(here,'-begin');
assert(exist('fskConfig','file')==2,'FSKReceiver:NotImplemented', ...
    'The FSK protocol and independent receiver have not been implemented.');
cfg=fskConfig();
rxCfg=rmfield(cfg,{'leadSamples','repetitions','frameSamples','guardSymbols', ...
    'frequencyOffsetHz','phaseOffsetRad'});
assert(fskCrc16(uint8('123456789'))==uint16(hex2dec('29B1')), ...
    'CRC-16/CCITT-FALSE standard check vector failed.');
assert(isequal(fskBitsToBytes(fskBytesToBits(uint8(0:255))),uint8((0:255).')), ...
    'MSB-first byte serialization failed.');
messages={'A','Hello, DUT! 2FSK 2026.',repmat('ASCII packet boundaries 0123456789. ',1,8),char(0:127)};
results=struct('name',{},'pass',{},'validFrames',{},'periodSamples',{});
for k=1:numel(messages)
    [wave,truth]=fskEncodeText(messages{k},cfg);
    direct=fskDecodeBits(truth.bits,cfg);
    assert(direct.complete&&strcmp(direct.message,messages{k}),'Direct protocol round trip failed.');
    z=filter(ones(cfg.sps,1)/cfg.sps,1,2*wave-1);
    r=fskDecodeWave(z,rxCfg);
    assert(r.complete&&strcmp(r.message,messages{k}),'Ideal soft receiver round trip failed.');
    results(end+1)=row(sprintf('ideal_%d',k),r); %#ok<AGROW>
end
% Public receiver config contains no transmitted text or exact source delay.
msg=repmat('Clock drift and long packets: 00112233445566778899. ',1,6);
for lead=[0 1 27 73 99 137 373]
    txCfg=cfg;txCfg.leadSamples=lead;
    [wave,~]=fskEncodeText(msg,txCfg);
    z=filter(ones(cfg.sps,1)/cfg.sps,1,2*wave-1);
    r=fskDecodeWave(z,rxCfg);
    assert(r.complete&&strcmp(r.message,msg),'Unknown sample phase recovery failed.');
    results(end+1)=row(sprintf('phase_%d',lead),r); %#ok<AGROW>
end
for ppm=[-2000 -500 500 2000]
    [wave,~]=fskEncodeText(msg,cfg);
    z=filter(ones(cfg.sps,1)/cfg.sps,1,2*wave-1);
    t=(1:1/(1+ppm*1e-6):numel(z)).';
    drifted=interp1((1:numel(z)).',z,t,'linear');
    r=fskDecodeWave(drifted,rxCfg);
    assert(r.complete&&strcmp(r.message,msg),'Sampling clock tracking failed.');
    results(end+1)=row(sprintf('clock_%dppm',ppm),r); %#ok<AGROW>
end
% Constant polarity plus small noise must not be recentered into random bits.
rng(1907,'twister');
for polarity=[-1 1]
    r=fskDecodeWave(polarity*ones(100*cfg.sps,1)+0.01*randn(100*cfg.sps,1),rxCfg);
    assert(all(r.bits==(polarity>0))&&~r.complete,'Constant symbol level was destroyed.');
    results(end+1)=row(sprintf('constant_%d',polarity),r); %#ok<AGROW>
end
[~,truth]=fskEncodeText('CRC rejection test',cfg);
oneFrame=truth.frames{1};
payloadStart=numel(cfg.preamble)+numel(cfg.sync)+8*cfg.headerBytes+1;
oneFrame(payloadStart)=1-oneFrame(payloadStart);
r=fskDecodeBits(oneFrame,cfg);
assert(~r.complete&&r.crcRejected>=1,'Corrupted payload was accepted.');
results(end+1)=struct('name','crc_rejection','pass',true,'validFrames',r.validFrameCount,'periodSamples',NaN);
bad=false;
try,fskEncodeText(char(200),cfg);catch,bad=true;end
assert(bad,'Non-ASCII input must be rejected.');
disp(struct2table(results));
end
function s=row(name,r)
s=struct('name',name,'pass',true,'validFrames',r.validFrameCount, ...
    'periodSamples',r.timingPeriodSamples(end));
end

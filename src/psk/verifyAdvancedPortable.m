function report=verifyAdvancedPortable()
% Portable source-package checks. Needs only this engineering folder.
% No Simulink run, work/ test fixture, playback, recording or RF hardware.
here=fileparts(mfilename('fullpath'));oldPath=path;
restore=onCleanup(@()path(oldPath));addpath(here,'-begin'); %#ok<NASGU>
names={'advProtocolConfig','advEncodeBytes','advDecodeBits','advHammingEncode', ...
    'advHammingDecode','advInterleave','advDeinterleave','advCrc16','advSha256', ...
    'advSoundcardConfig','advSoundcardTransmit','advSoundcardReceive', ...
    'advSoundcardModulate','advSoundcardDemodulate'};
for k=1:numel(names)
    resolved=which(names{k});
    assert(startsWith(resolved,[here filesep],'IgnoreCase',true), ...
        'ADV:PortableDependency','%s resolves outside the package: %s',names{k},resolved);
end
checks={'All modem/protocol dependencies resolve inside this package'};
assert(advCrc16(uint8('123456789'))==hex2dec('29B1'),'ADV:PortableCrc','CRC known vector failed.');
[~,hash]=advSha256(uint8('abc'));
assert(strcmp(hash,'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'), ...
    'ADV:PortableHash','SHA-256 known vector failed.');
checks{end+1}='Independent CRC-16 and SHA-256 known vectors';
single=0;doubleErrors=0;
for value=0:15
    bits=double(bitget(uint8(value),4:-1:1)).';coded=advHammingEncode(bits);
    for a=1:8
        damaged=coded;damaged(a)=1-damaged(a);
        [restored,status]=advHammingDecode(damaged);
        assert(isequal(restored,bits)&&status.correctedErrors==1,'ADV:PortableSecded','Single error not corrected.');
        single=single+1;
        for b=a+1:8
            damaged=coded;damaged([a b])=1-damaged([a b]);
            [~,status]=advHammingDecode(damaged);
            assert(status.detectedDoubleErrors==1,'ADV:PortableSecded','Double error not detected.');
            doubleErrors=doubleErrors+1;
        end
    end
end
checks{end+1}='All 128 single-error and 448 double-error Hamming cases';
cfg=advProtocolConfig();bytes=uint8(mod((0:512).'*73+29,256));
for lineCode={'NRZ','Manchester'}
    txCfg=cfg;txCfg.lineCode=lineCode{1};txCfg.payloadType=2;
    [bits,truth]=advEncodeBytes(bytes,txCfg);
    received=advDecodeBits([zeros(31,1);bits;ones(19,1)],cfg);
    assert(received.complete&&isequal(received.bytes,bytes)&&truth.frameCount==3, ...
        'ADV:PortableProtocol','513-byte binary packet failed.');
    reversed=advDecodeBits(vertcat(truth.frames{3:-1:1}),cfg);
    assert(reversed.complete&&isequal(reversed.bytes,bytes),'ADV:PortableReorder','Out-of-order fragments failed.');
    missing=advDecodeBits(vertcat(truth.frames{[1 3]}),cfg);
    assert(~missing.complete&&isempty(missing.bytes),'ADV:PortableMissing','Missing fragment was accepted.');
end
checks{end+1}='513 bytes including all byte values: NRZ/Manchester, reordering, missing fragment';
[~,a]=advEncodeBytes(bytes,cfg);[~,b]=advEncodeBytes(uint8(255-bytes),cfg);
mixed=advDecodeBits([a.frames{1};b.frames{2};a.frames{3}],cfg);
assert(~mixed.complete&&isempty(mixed.bytes),'ADV:PortableSplice','Mixed messages were accepted.');
checks{end+1}='Different-message fragments never splice';
audioCfg=advSoundcardConfig();audioBytes=uint8(mod((0:280).'*31+7,256));
wave=advSoundcardTransmit(audioBytes,audioCfg);
warped=interp1((0:numel(wave)-1)',wave, ...
    (0:1/(1+1700e-6):numel(wave)-1)','linear');
received=advSoundcardReceive([zeros(819,1);-0.12*warped],audioCfg);
assert(received.complete&&isequal(received.bytes,audioBytes),'ADV:PortableAudioClock', ...
    'Audio with unknown delay, negative gain, and 1700ppm drift failed.');
checks{end+1}='Two-fragment real audio, 819-sample delay, negative gain, 1700ppm clock drift';
stereo=advSoundcardReceive([zeros(size(wave)) wave],audioCfg);
assert(stereo.complete&&isequal(stereo.bytes,audioBytes)&&stereo.audio.selectedChannel==2, ...
    'ADV:PortableStereo','Right-only audio failed.');
checks{end+1}='Right-channel-only line input';
wavPath=[tempname '.wav'];wrongPath=[tempname '.wav'];
cleanup=onCleanup(@()eraseOwnedWavs(wavPath,wrongPath)); %#ok<NASGU>
advSoundcardTransmit(audioBytes,audioCfg,wavPath);
quantized=advSoundcardReceive(wavPath,audioCfg);
assert(quantized.complete&&isequal(quantized.bytes,audioBytes),'ADV:PortableWav','PCM WAV read-back failed.');
audiowrite(wrongPath,wave,44100,'BitsPerSample',16);
rejected=false;
try,advSoundcardReceive(wrongPath,audioCfg);
catch err,rejected=strcmp(err.identifier,'ADV:SoundcardSampleRate');end
assert(rejected,'ADV:PortableRate','Mismatched WAV sample rate was silently accepted.');
checks{end+1}='16-bit WAV read-back and wrong-sample-rate rejection';
silent=advSoundcardReceive(zeros(25000,1),audioCfg);
assert(~silent.complete&&isempty(silent.bytes),'ADV:PortableSilence','Silence falsely accepted.');
checks{end+1}='Silence never produces a complete payload';
report=struct('passed',true,'checkCount',numel(checks),'checks',{checks}, ...
    'hammingSingleCases',single,'hammingDoubleCases',doubleErrors, ...
    'audioDeviceUsed',false,'physicalSoundcardTested',false, ...
    'scope','Portable protocol and offline audio smoke checks; main SLX validation is separate.');
fprintf('PORTABLE_ADVANCED: %d checks PASS; no playback or recording\n',report.checkCount);
end
function eraseOwnedWavs(first,second)
if isfile(first),delete(first);end
if isfile(second),delete(second);end
end

function result=advSoundcardReceive(audio,cfg)
% Decode supplied audio or a recorded WAV file; never record automatically.
if nargin<2||isempty(cfg),cfg=advSoundcardConfig();end
sourcePath='';
if ischar(audio)||isstring(audio)
    sourcePath=char(audio);[audio,fs]=audioread(sourcePath);
    assert(fs==cfg.fs,'ADV:SoundcardSampleRate', ...
        'Recorded file sample rate %g does not match configured %g Hz.',fs,cfg.fs);
end
demod=advSoundcardDemodulate(audio,cfg);
result=advDecodeBits(demod.bits,cfg.protocol);
result.audio=demod;result.wavPath=sourcePath;
result.audioDeviceUsed=false;result.physicalLinkTested=false;
end

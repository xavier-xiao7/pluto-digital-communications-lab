function [radioWave,metadata]=plutoFskMakeWave(message,changes)
% Teacher-derived 8/12 kHz FSK, genuinely interpolated from 100 kHz to 1 MHz.
if nargin<2,changes=struct();end
options=plutoFskOptions(changes);here=fileparts(mfilename('fullpath'));
oldPath=path;guard=onCleanup(@()path(oldPath));addpath(fullfile(here,'fskCore'),'-begin');
cfg=fskConfig();[wire,transport]=plutoFskPackText(message);[bits,truth]=fskEncodeText(wire,cfg);
n=(0:numel(bits)-1).';
base=(1-bits).*exp(1i*2*pi*cfg.f0*n/cfg.fs)+bits.*exp(1i*2*pi*cfg.f1*n/cfg.fs);
radioWave=resample(base,10,1,32,8.6);
% Keep both tones away from hardware DC throughout the +/-80 kHz CFO range.
n=(0:numel(radioWave)-1).';
radioWave=radioWave.*exp(1i*2*pi*options.digitalIfHz*n/options.radioSampleRate);
% A cyclic playback buffer must not exceed its declared amplitude at FIR edges.
peak=max(abs(radioWave));radioWave=complex(single(radioWave*(options.txAmplitude/peak)));
assert(numel(radioWave)<=16777216,'PLUTO:WaveLength','Transmission buffer exceeds Pluto cyclic-buffer limit.');
metadata=struct('message',char(message),'sourceSampleRate',cfg.fs,'radioSampleRate',options.radioSampleRate, ...
    'bitRate',cfg.baud,'f0Hz',cfg.f0,'f1Hz',cfg.f1,'interpolation',10, ...
    'digitalIfHz',options.digitalIfHz,'radioTone0Hz',options.digitalIfHz+cfg.f0, ...
    'radioTone1Hz',options.digitalIfHz+cfg.f1, ...
    'resampleFilterHalfLength',32,'resampleKaiserBeta',8.6,'sourceSamples',numel(base), ...
    'radioSamples',numel(radioWave),'bufferSeconds',numel(radioWave)/options.radioSampleRate, ...
    'peakAmplitude',double(max(abs(radioWave))),'frameCount',truth.frameCount, ...
    'copiesPerBuffer',truth.expectedCopies,'messageId',double(truth.messageId),'transport',transport,'wireMessage',wire);
end

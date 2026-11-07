function cfg=fskConfig()
% Public protocol, waveform, channel and receiver parameters for 2FSK.
cfg.fs=100000;cfg.baud=1000;cfg.sps=cfg.fs/cfg.baud;
cfg.f0=8000;cfg.f1=12000;cfg.fc=(cfg.f0+cfg.f1)/2;
cfg.frameSamples=2000;cfg.signalPower=1;
cfg.ebNo=25;cfg.channelMode='combined';
cfg.awgnSeed=67;cfg.fadingSeed=73;
cfg.frequencyOffsetHz=0;cfg.phaseOffsetRad=0;
cfg.sync=double(dec2bin(hex2dec('D391C5A7'),32).'-'0');
cfg.preamble=repmat([1;0],64,1);
cfg.maxPayload=64;cfg.repetitions=2;cfg.headerBytes=6;
cfg.leadSamples=373;cfg.guardSymbols=12;
cfg.frameHeaderErrors=2;
% Second-order transition-driven clock recovery. No TX timing is used.
cfg.timingMode='pll';cfg.pllAlpha=0.70;cfg.pllBeta=0.002;
cfg.timingHysteresis=0.15;cfg.minEdgeSpacing=0.45;
cfg.maxClockPpm=10000;cfg.fixedPhaseSamples=cfg.sps/2;
end

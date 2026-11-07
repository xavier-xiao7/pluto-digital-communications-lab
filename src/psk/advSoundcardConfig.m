function cfg=advSoundcardConfig()
% Offline-first, real-valued soundcard line modem. No device is opened.
cfg.fs=48000;cfg.baud=1000;cfg.sps=48;
cfg.f0=4000;cfg.f1=8000;cfg.amplitude=0.60;
cfg.leadSamples=2400;cfg.tailSamples=2400;
cfg.pllAlpha=0.70;cfg.pllBeta=0.002;
cfg.timingHysteresis=0.15;cfg.minEdgeSpacing=0.45;
cfg.maxClockPpm=10000;
cfg.protocol=advProtocolConfig();
end

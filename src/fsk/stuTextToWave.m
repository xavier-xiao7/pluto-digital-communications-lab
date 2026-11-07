%% ASCII text to framed binary waveform (teacher interface)
% Source encoding only. Actual 2FSK modulation is in stuFskSimulation.slx.
if ~exist('cfg','var'), cfg=fskConfig(); end
if ~exist('msg','var'), msg='Hello, DUT! 2FSK experiment 2026.'; end
[txWave,txTruth]=fskEncodeText(msg,cfg);
fs=cfg.fs;bitRate=cfg.baud;samplesPerBit=cfg.sps;
fprintf('TX: %d ASCII bytes, %d unique protocol frames.\n',numel(msg),txTruth.frameCount);

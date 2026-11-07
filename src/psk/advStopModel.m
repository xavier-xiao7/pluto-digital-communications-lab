function advStopModel()
% GUI Run callback uses separate workspace logging, not a stale out object.
assert(evalin('base','exist(''rxWave'',''var'')')==1,'ADV:MissingOutput','No fresh received waveform was logged.');
wave=evalin('base','rxWave');cfg=evalin('base','cfg');
result=advReceivePsk(wave.Data(:),advPskConfig(cfg.modulation));
assignin('base','advancedLastResult',result);
fprintf('Model callback: complete=%d, bytes=%d, valid frame copies=%d\n',result.complete,numel(result.bytes),result.validFrameCount);
end

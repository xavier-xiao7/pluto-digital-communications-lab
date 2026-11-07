%% Teacher receive script using only received samples and public PHY
rxResult=advReceivePsk(out.rxWave.Data(:),advPskConfig(cfg.modulation));
receivedBytes=rxResult.bytes;
fprintf('Complete=%d, valid frame copies=%d, bytes=%d\n',rxResult.complete,rxResult.validFrameCount,numel(receivedBytes));
if rxResult.complete && rxResult.payloadType==1
 receivedMessage=native2unicode(receivedBytes.','UTF-8');disp(receivedMessage);
end

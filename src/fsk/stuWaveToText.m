%% Recover text from received waveform and public protocol only
% No reference to msg, txWave, txTruth, or source alignment.
if ~exist('cfg','var'), cfg=fskConfig(); end
rxResult=fskDecodeWave(out.rxWave.Data(:),cfg);
receivedMessage=rxResult.message;
fprintf('RX: complete=%d, CRC-valid frame copies=%d\n',rxResult.complete,rxResult.validFrameCount);
if rxResult.complete, disp(receivedMessage); end

function out=advPostSimulation(out,publicReceiverConfig)
% PostSimFcn is used because SimulationOutput is unavailable during StopFcn.
rx=advReceivePsk(out.rxWave.Data(:),publicReceiverConfig);
out.advancedRx=rx;
end

function commLabModelCallbacks(action,mode)
% In-memory Run-button callbacks for the FSK model; no source-model writes.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
if strcmp(mode,'PSK')
    assertIdle('stuFskSimulation');
    addpath(fullfile(root,'src','psk'));
    advInitModel;
    return;
end
assert(strcmp(mode,'2FSK'));
addpath(fullfile(root,'src','fsk'));
mdl='stuFskSimulation';
switch action
    case 'init'
        assertIdle('stuAdvancedSimulation');
        cfg=fskConfig(); msg='Hello, world! Lab 2FSK communication experiment 2026.';
        [txWave,txTruth]=fskEncodeText(msg,cfg);
        assignin('base','cfg',cfg); assignin('base','txWave',txWave); assignin('base','txTruth',txTruth);
        evalin('base','clear rxWave fskLastResult');
        set_param(mdl,'StopTime',num2str((numel(txWave)-cfg.frameSamples)/cfg.fs,16), ...
            'EnablePacing','off');
        set_param([mdl sprintf('/AWGN\nChannel')],'Commented','off');
        set_param([mdl '/SISO Fading Channel1'],'Commented','off');
    case 'stop'
        assert(evalin('base','exist(''rxWave'',''var'')')==1,'本次仿真尚未产生接收波形。');
        wave=evalin('base','rxWave'); cfg=fskConfig();
        result=fskDecodeWave(wave.Data(:),cfg); assignin('base','fskLastResult',result);
        fprintf('FSK: complete=%d, valid frames=%d\n',result.complete,result.validFrameCount);
        if result.complete,disp(result.message);end
    otherwise
        error('Unknown launcher callback action.');
end
end
function assertIdle(other)
if bdIsLoaded(other)
    assert(strcmp(get_param(other,'SimulationStatus'),'stopped'),'请等待另一模型运行结束，再启动当前模型。');
end
end

function createLabModel(mdl)
% Assemble a fresh model from installed MathWorks library blocks.
% No binary template, external workspace or private metadata is required.
load_system('simulink');load_system('dspsrcs4');load_system('commchan3');
new_system(mdl);
add_block(sprintf('dspsrcs4/Signal From\nWorkspace'),[mdl sprintf('/Signal From\nWorkspace')]);
add_block(sprintf('commchan3/AWGN\nChannel'),[mdl sprintf('/AWGN\nChannel')]);
add_block('commchan3/SISO Fading Channel',[mdl '/SISO Fading Channel1'], ...
 'InheritSampleRate','on','PathDelays','0.001','AveragePathGains','-20', ...
 'NormalizePathGains','on','FadingDistribution','Rician','KFactor','3', ...
 'DirectPathDopplerShift','1','DirectPathInitialPhase','1','MaximumDopplerShift','2', ...
 'DopplerSpectrum','doppler(''Jakes'')','RandomStream','mt19937ar with seed', ...
 'Seed','cfg.fadingSeed','PathGainsOutputPort','off','ChannelFilterDelayOutputPort','off', ...
 'SimulateUsing','Interpreted execution','Visualization','Off');
add_block('simulink/Math Operations/Complex to Real-Imag',[mdl sprintf('/Complex to\nReal-Imag')],'Output','Real');
add_block('simulink/Sinks/Scope',[mdl '/Scope']);
add_block('built-in/SpectrumAnalyzer',[mdl sprintf('/Spectrum\nAnalyzer')]);
add_block('simulink/Sinks/To Workspace',[mdl '/To Workspace1']);
set_param(mdl,'ModelVersionFormat','1.0','Creator','Digital Communications Lab');
end

function options=plutoFskOptions(changes)
% Public RF bridge parameters; no hardware access.
options=struct('radioSampleRate',1e6,'digitalIfHz',100000,'txGainDb',-50,'txAmplitude',0.25, ...
    'rxGainDb',30,'samplesPerFrame',65536,'maxCfoHz',80000, ...
    'minimumPairSnrDb',8,'maxCaptureSeconds',30,'startAtUtc','');
if nargin>0
    names=fieldnames(changes);
    for k=1:numel(names)
        assert(isfield(options,names{k}),'PLUTO:UnknownOption','Unknown option: %s',names{k});
        options.(names{k})=changes.(names{k});
    end
end
assert(options.radioSampleRate==1e6,'PLUTO:SampleRate','This bridge is validated at 1 MHz.');
assert(options.digitalIfHz==100000,'PLUTO:DigitalIF','Both ends use the fixed 100 kHz digital IF.');
validateattributes(options.txGainDb,{'numeric'},{'scalar','finite','>=',-89.75,'<=',-10});
validateattributes(options.txAmplitude,{'numeric'},{'scalar','finite','>',0,'<=',0.5});
validateattributes(options.rxGainDb,{'numeric'},{'scalar','integer','>=',0,'<=',60});
validateattributes(options.samplesPerFrame,{'numeric'},{'scalar','integer','>=',4096,'<=',1048576});
assert(mod(options.samplesPerFrame,2)==0);
validateattributes(options.maxCfoHz,{'numeric'},{'scalar','finite','>=',1000,'<=',80000});
validateattributes(options.minimumPairSnrDb,{'numeric'},{'scalar','finite','>=',3,'<=',30});
validateattributes(options.maxCaptureSeconds,{'numeric'},{'scalar','finite','>',0,'<=',30});
assert(ischar(options.startAtUtc)||(isstring(options.startAtUtc)&&isscalar(options.startAtUtc)));
options.startAtUtc=char(options.startAtUtc);
end

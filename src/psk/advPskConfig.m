function cfg = advPskConfig(modulation)
%ADVPSKCONFIG Public PHY parameters, never transmitter/channel truth.
if nargin==0, modulation='BPSK'; end
cfg.modulation=upper(char(modulation));
assert(ismember(cfg.modulation,{'BPSK','QPSK'}),'PSK:Modulation','Use BPSK or QPSK.');
cfg.Fs=48000; cfg.symbolRate=3000; cfg.sps=16; cfg.fc=8000;
cfg.rolloff=0.5; cfg.filterSpan=10;
cfg.bitsPerSymbol=1+strcmp(cfg.modulation,'QPSK');
cfg.qGain=double(cfg.bitsPerSymbol==2);
cfg.symbolNormalization=1/sqrt(cfg.bitsPerSymbol);
cfg.trainingLength=127; cfg.dataSymbolsPerTile=256; cfg.guardSymbols=16;
cfg.maxCfoHz=350; cfg.correlationThreshold=0.58;
cfg.maxClockPpm=5000;
cfg.carrierAlpha=0.065; cfg.carrierBeta=0.0010;
% Public deterministic x^7+x^3+1 maximal-length binary sequence.
state=true(7,1); pn=false(cfg.trainingLength,1);
for k=1:cfg.trainingLength
    pn(k)=state(7); feedback=xor(state(7),state(3));
    state=[feedback;state(1:6)];
end
cfg.trainingIBits=double(pn);
cfg.trainingQBits=double(circshift(pn,43));
cfg.trainingSymbols=((1-2*cfg.trainingIBits)+ ...
    1i*cfg.qGain*(1-2*cfg.trainingQBits))*cfg.symbolNormalization;
end

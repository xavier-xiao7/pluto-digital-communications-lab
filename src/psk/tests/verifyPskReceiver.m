function results = verifyPskReceiver()
% Independent waveform tests. The receiver receives samples and public cfg only.
assert(exist('advPskConfig','file') == 2, ...
    'PSK:MissingImplementation','Public PSK config is not implemented yet.');
assert(exist('advPskFrameBits','file') == 2, ...
    'PSK:MissingImplementation','PSK public training/framing is not implemented yet.');
assert(exist('advReceivePsk','file') == 2, ...
    'PSK:MissingImplementation','PSK synchronization receiver is not implemented yet.');
cases = {
    'BPSK', 9001, 0,   0,     0,    Inf, 0;
    'BPSK', 9001, 7,   117,   1.13, 25,  0;
    'BPSK', 4237, 29, -219,  -2.61, 18,  0;
    'QPSK', 9001, 23,  117,   1.13, 25,  0;
    'QPSK', 4237, 41, -219,  -2.61, 18,  0;
    'QPSK', 18001,13,  81,    2.90, 25,  1200;
    'BPSK', 18001,31, -81,   -2.30, 25, -1200;
    };
results = struct([]);
for k = 1:size(cases,1)
    mode = cases{k,1}; cfg = advPskConfig(mode);
    rng(700+k,'twister'); bits = randi([0 1],cases{k,2},1);
    [ib,qb,active,meta] = advPskFrameBits({bits},cfg);
    % Independently reproduce the public graph's +/-1 I/Q mapping and filters.
    symbols = ((1-2*double(ib))+1i*cfg.qGain*(1-2*double(qb))) ...
        *cfg.symbolNormalization .* double(active);
    impulses = zeros(numel(symbols)*cfg.sps,1);
    impulses(1:cfg.sps:end) = symbols;
    h = rcosdesign(cfg.rolloff,cfg.filterSpan,cfg.sps,'sqrt').';
    tx = conv(impulses,sqrt(cfg.sps)*h);
    n = (0:numel(tx)-1).';
    rx = tx .* exp(1i*(cases{k,5}+2*pi*cases{k,4}*n/cfg.Fs));
    if isfinite(cases{k,6})
        variance = 10^(-cases{k,6}/10)*cfg.sps/cfg.bitsPerSymbol;
        rx = rx + sqrt(variance/2)*(randn(size(rx))+1i*randn(size(rx)));
    end
    rx = conv(rx,h/sqrt(cfg.sps));
    if cases{k,7} ~= 0
        % Independent time warp, unknown to the receiver.
        idx = (1:(1+cases{k,7}*1e-6):numel(rx)).';
        rx = interp1((1:numel(rx)).',rx,idx,'linear');
    end
    rx = [zeros(cases{k,3},1);rx;zeros(2*cfg.filterSpan*cfg.sps,1)];
    r = advReceivePsk(rx,cfg);
    assert(numel(r.bits)>=numel(bits),'PSK:LostTiles', ...
        '%s case %d lost PHY tiles: got %d bits for %d.',mode,k,numel(r.bits),numel(bits));
    errors = nnz(r.bits(1:numel(bits)) ~= bits);
    assert(errors==0,'PSK:BitErrors','%s case %d has %d bit errors.',mode,k,errors);
    assert(numel(r.tiles)==meta.tileCount,'PSK:TileCount', ...
        '%s case %d detected %d/%d PHY tiles.',mode,k,numel(r.tiles),meta.tileCount);
    results(k).mode=mode; results(k).bitCount=numel(bits); %#ok<AGROW>
    results(k).delaySamples=cases{k,3}; results(k).cfoHz=cases{k,4};
    results(k).phaseRadians=cases{k,5}; results(k).ebNo=cases{k,6};
    results(k).clockPpm=cases{k,7}; results(k).errors=errors;
    results(k).tileCount=numel(r.tiles); results(k).coarseCfoHz=r.coarseCfoHz;
    fprintf('PSK receiver %d/%d PASS %s: %d bits, %d tiles, CFO %.3f Hz\n', ...
        k,size(cases,1),mode,numel(bits),numel(r.tiles),r.coarseCfoHz);
end
end

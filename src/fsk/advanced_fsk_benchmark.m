function result = advanced_fsk_benchmark(outputDir)
%ADVANCED_FSK_BENCHMARK Known-timing noncoherent orthogonal binary FSK.
%   RESULT = ADVANCED_FSK_BENCHMARK() runs a reproducible, batched, actual
%   waveform Monte Carlo benchmark and writes JSON, MAT, and a hidden PNG.
%   This is NOT a packet/PLL/frame acquisition test or a radio experiment.
%   See advanced_benchmark_notes.md for predeclared acceptance conditions.
%
%   Every Eb/N0 and frequency-offset point uses 100000 bits with 100 samples
%   per bit. No samples are replaced by synthetic sufficient statistics.
%   Base MATLAB only; compatible with R2025a.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(outputDir)
    outputDir = fullfile(projectRoot, '验证');
end
if ~isfolder(outputDir)
    mkdir(outputDir);
end

% Preserve the caller's random stream. Each point has its own fixed seed.
previousRng = rng;
rngCleanup = onCleanup(@() rng(previousRng)); %#ok<NASGU>
benchmarkTimer = tic;

cfg = struct;
cfg.sampleRateHz = 100000;
cfg.bitRateHz = 1000;
cfg.samplesPerBit = 100;
cfg.toneFrequenciesHz = [8000 12000];
cfg.signalPower = 1;
cfg.bitsPerSymbol = 1;
cfg.ebNoDb = 0:2:12;
cfg.frequencyOffsetsHz = [0 100 300 800];
cfg.bitsPerPoint = 100000;
cfg.batchBits = 1000;
cfg.seedBase = 20261025;
cfg.initialPhaseRad = 0.37;
cfg.phaseRotationsRad = [pi/7 pi/2 pi];
cfg.confidenceLevel = 0.95;
cfg.theoryFamilyConfidenceLevel = 0.999;
cfg.noiseSampleRelativeTolerance = 0.005;
cfg.noiseProjectionRelativeTolerance = 0.03;
cfg.noiseCorrelationTolerance = 0.03;
cfg.firAbsoluteTolerance = 1e-10;
cfg.phaseRelativeTolerance = 1e-10;

assert(cfg.sampleRateHz / cfg.bitRateHz == cfg.samplesPerBit);
assert(mod(cfg.bitsPerPoint, cfg.batchBits) == 0);
sampleTime = (0:cfg.samplesPerBit-1).' / cfg.sampleRateHz;
toneBank = exp(1i * 2*pi * sampleTime * cfg.toneFrequenciesHz);
gram = toneBank' * toneBank / cfg.samplesPerBit;
orthogonalityError = max(abs(gram - eye(2)), [], 'all');
assert(orthogonalityError < 1e-12, ...
    'FSKBenchmark:NonOrthogonal', 'The configured two tones are not orthogonal.');

result = struct;
result.schemaVersion = '1.0';
result.createdAtUtc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
result.matlabVersion = version;
result.matlabRelease = version('-release');
result.parameters = cfg;
result.metadata = struct( ...
    'scope', 'Independent known-symbol-timing noncoherent orthogonal binary FSK detector', ...
    'notValidatedHere', {{'symbol-timing acquisition', 'PLL tracking', ...
        'frame synchronization', 'CRC or text recovery', 'Simulink full chain', ...
        'multipath or fading', 'real SDR/RF hardware'}}, ...
    'waveform', 'Actual unit-power complex sinusoidal samples; 100 samples per bit', ...
    'noise', 'Actual independent circular complex Gaussian noise on every sample', ...
    'noiseVarianceFormula', 'sigma2 = signalPower * samplesPerBit / 10^(EbNoDb/10)', ...
    'quadratureVariance', 'Real and imaginary noise variances each equal sigma2/2', ...
    'detector', '100-sample complex correlation mean per tone, compare squared magnitudes', ...
    'timing', 'Exact transmitted symbol boundaries supplied to the detector', ...
    'frequencyOffsetConvention', 'Positive offset shifts both transmitted tones; RX tones remain fixed', ...
    'phaseTest', 'Paired common rotation of complete received samples, not independent phase BER trials', ...
    'zeroOffsetTheory', 'Pb = 0.5 * exp(-10^(EbNoDb/10)/2)', ...
    'nonzeroOffsetTheory', 'No zero-offset theoretical BER is assigned to offset conditions', ...
    'samplingRule', 'Fixed 100000 bits per point; no error-count stopping', ...
    'confidenceInterval', 'Pointwise exact two-sided 95% Clopper-Pearson binomial interval', ...
    'zeroErrorsMeaning', 'Zero observed errors is not proof of zero underlying error probability', ...
    'rngAlgorithm', 'twister; one documented seed per point; caller state restored', ...
    'toolboxRequirement', 'Base MATLAB only', ...
    'sources', {{ ...
        'https://www.mathworks.com/help/comm/ref/awgnchannel.html', ...
        'https://www.mathworks.com/help/comm/ug/analytical-expressions-used-in-berawgn-function-and-bit-error-rate-analysis-app.html', ...
        'https://www.mathworks.com/help/stats/binofit.html', ...
        'https://www.mathworks.com/help/matlab/ref/betaincinv.html'}});

nPoints = numel(cfg.ebNoDb) * numel(cfg.frequencyOffsetsHz);
points = repmat(pointTemplate(), nPoints, 1);
pointIndex = 0;
for offsetIndex = 1:numel(cfg.frequencyOffsetsHz)
    offsetHz = cfg.frequencyOffsetsHz(offsetIndex);
    for ebIndex = 1:numel(cfg.ebNoDb)
        pointIndex = pointIndex + 1;
        seed = cfg.seedBase + 1000*(offsetIndex-1) + ebIndex;
        points(pointIndex) = runPoint(cfg, toneBank, sampleTime, ...
            cfg.ebNoDb(ebIndex), offsetHz, seed);
        p = points(pointIndex);
        fprintf(['[advanced_fsk] offset=%4g Hz, Eb/N0=%2g dB, ' ...
            'errors=%5d/%d, BER=%.6g, CI95=[%.6g, %.6g]\n'], ...
            p.frequencyOffsetHz, p.ebNoDb, p.errors, p.bits, ...
            p.berEstimate, p.ci95Lower, p.ci95Upper);
    end
end
result.points = points;

baseline = points([points.frequencyOffsetHz] == 0);
v = struct;
v.orthogonalityMaxAbsError = orthogonalityError;
v.orthogonalityPassed = orthogonalityError < 1e-12;
v.actualWaveformBits = sum([points.bits]);
v.actualComplexSamples = sum([points.samples]);
v.minimumBitsPerPoint = min([points.bits]);
v.sampleCountPassed = v.minimumBitsPerPoint >= 100000;
v.maxSignalPowerAbsError = max([points.maxSignalPowerAbsError]);
v.signalPowerPassed = v.maxSignalPowerAbsError < 1e-12;
v.maxFirCorrelationAbsError = max([points.firCorrelationMaxAbsError]);
v.firCorrelationPassed = v.maxFirCorrelationAbsError < cfg.firAbsoluteTolerance;
v.maxPhaseEnergyRelativeError = max([points.phaseEnergyMaxRelativeError]);
v.phaseDecisionDifferences = sum([points.phaseDecisionDifferences]);
v.phaseInvariancePassed = v.maxPhaseEnergyRelativeError < ...
    cfg.phaseRelativeTolerance && v.phaseDecisionDifferences == 0;
v.maxNoiseSampleRelativeError = max(abs([points.noiseSamplePowerRatio]-1));
v.sampleNoiseScalingPassed = v.maxNoiseSampleRelativeError < ...
    cfg.noiseSampleRelativeTolerance;
projectionRatios = [points.noiseProjectionPowerRatios];
v.maxNoiseProjectionRelativeError = max(abs(projectionRatios-1));
v.projectionNoiseScalingPassed = v.maxNoiseProjectionRelativeError < ...
    cfg.noiseProjectionRelativeTolerance;
v.maxNoiseProjectionCorrelationMagnitude = max([points.noiseProjectionCorrelationMagnitude]);
v.projectionNoiseIndependencePassed = v.maxNoiseProjectionCorrelationMagnitude < ...
    cfg.noiseCorrelationTolerance;
v.theoryFamilyConfidenceLevel = cfg.theoryFamilyConfidenceLevel;
v.theoryPointConfidenceLevel = 1 - ...
    (1-cfg.theoryFamilyConfidenceLevel)/numel(cfg.ebNoDb);
v.theoryWithinFamilywiseIntervals = [baseline.theoryWithinFamilywiseInterval];
v.zeroOffsetTheoryPassed = all(v.theoryWithinFamilywiseIntervals);
v.theoryTestInterpretation = ['Bonferroni simultaneous coverage at least 99.9% ' ...
    'for the 7 zero-offset points; finite random false failures remain possible.'];
v.allPassed = v.orthogonalityPassed && v.sampleCountPassed && ...
    v.signalPowerPassed && v.firCorrelationPassed && v.phaseInvariancePassed && ...
    v.sampleNoiseScalingPassed && v.projectionNoiseScalingPassed && ...
    v.projectionNoiseIndependencePassed && v.zeroOffsetTheoryPassed;
result.validation = v;
result.elapsedSeconds = toc(benchmarkTimer);
result.artifacts = struct( ...
    'json', fullfile(outputDir, 'advanced_benchmark.json'), ...
    'mat', fullfile(outputDir, 'advanced_benchmark.mat'), ...
    'performancePng', fullfile(outputDir, 'advanced_benchmark_performance.png'));

% Write numerical evidence before rendering, so a graphics failure does not
% discard Monte Carlo measurements. Re-save after the figure status update.
result.figureSaved = false;
saveEvidence(result);
renderFigure(result);
result.figureSaved = true;
saveEvidence(result);
fprintf('[advanced_fsk] allPassed=%d; elapsed %.1f s; %s\n', ...
    result.validation.allPassed, result.elapsedSeconds, result.artifacts.json);
if ~result.validation.allPassed
    warning('FSKBenchmark:ValidationFailed', ...
        'Benchmark checks failed; numerical evidence was retained for diagnosis.');
end
end

function p = runPoint(cfg, toneBank, sampleTime, ebNoDb, offsetHz, seed)
rng(seed, 'twister');
pointTimer = tic;
gamma = 10^(ebNoDb/10);
sigma2 = cfg.signalPower * cfg.samplesPerBit / gamma;
noiseStdPerQuadrature = sqrt(sigma2/2);
offsetToneBank = exp(1i * 2*pi * sampleTime * ...
    (cfg.toneFrequenciesHz + offsetHz));

errors = 0;
bitsTested = 0;
sampleNoiseEnergy = 0;
projectedNoiseEnergy = zeros(2,1);
projectedNoiseCross = 0;
maxSignalPowerAbsError = 0;
firError = 0;
phaseEnergyError = 0;
phaseDecisionDifferences = 0;

while bitsTested < cfg.bitsPerPoint
    batchBits = min(cfg.batchBits, cfg.bitsPerPoint-bitsTested);
    bits = randi([0 1], 1, batchBits);
    % The nominal 8/12 kHz tones each complete an integer number of cycles
    % per symbol. Carry the extra offset phase continuously across symbols.
    symbolStarts = bitsTested + (0:batchBits-1);
    symbolPhase = exp(1i * (cfg.initialPhaseRad + 2*pi * ...
        mod(offsetHz * symbolStarts / cfg.bitRateHz, 1)));
    transmitted = sqrt(cfg.signalPower) * ...
        offsetToneBank(:,bits+1) .* symbolPhase;
    noise = noiseStdPerQuadrature * ...
        (randn(cfg.samplesPerBit,batchBits) + ...
         1i*randn(cfg.samplesPerBit,batchBits));
    received = transmitted + noise;

    correlations = toneBank' * received / cfg.samplesPerBit;
    energies = abs(correlations).^2;
    decoded = energies(2,:) > energies(1,:);
    errors = errors + nnz(decoded ~= bits);

    sampleNoiseEnergy = sampleNoiseEnergy + sum(abs(noise).^2, 'all');
    noiseCorrelations = toneBank' * noise / cfg.samplesPerBit;
    projectedNoiseEnergy = projectedNoiseEnergy + ...
        sum(abs(noiseCorrelations).^2, 2);
    projectedNoiseCross = projectedNoiseCross + ...
        sum(noiseCorrelations(1,:) .* conj(noiseCorrelations(2,:)));

    if bitsTested == 0
        maxSignalPowerAbsError = max(abs(abs(transmitted).^2 - ...
            cfg.signalPower), [], 'all');
        % A short actual contiguous waveform verifies equivalence to a
        % causal 100-tap matched FIR at the exact symbol end points.
        checkBits = min(8,batchBits);
        shortReceived = received(:,1:checkBits);
        shortCorrelations = correlations(:,1:checkBits);
        for toneIndex = 1:2
            firTaps = conj(flipud(toneBank(:,toneIndex))) / cfg.samplesPerBit;
            firOutput = filter(firTaps, 1, shortReceived(:));
            firAtSymbolEnds = firOutput(cfg.samplesPerBit:cfg.samplesPerBit:end).';
            firError = max(firError, max(abs(firAtSymbolEnds - ...
                shortCorrelations(toneIndex,:))));
        end
        baseEnergy = abs(shortCorrelations).^2;
        baseDecisions = baseEnergy(2,:) > baseEnergy(1,:);
        for rotation = cfg.phaseRotationsRad
            rotated = toneBank' * (shortReceived * exp(1i*rotation)) / cfg.samplesPerBit;
            rotatedEnergy = abs(rotated).^2;
            energyScale = max(max(baseEnergy, [], 'all'), eps);
            phaseEnergyError = max(phaseEnergyError, ...
                max(abs(rotatedEnergy-baseEnergy), [], 'all') / energyScale);
            phaseDecisionDifferences = phaseDecisionDifferences + ...
                nnz((rotatedEnergy(2,:) > rotatedEnergy(1,:)) ~= baseDecisions);
        end
    end
    bitsTested = bitsTested + batchBits;
end

p = pointTemplate();
p.ebNoDb = ebNoDb;
p.frequencyOffsetHz = offsetHz;
p.seed = seed;
p.errors = errors;
p.bits = bitsTested;
p.samples = bitsTested * cfg.samplesPerBit;
p.berEstimate = errors / bitsTested;
[p.ci95Lower, p.ci95Upper] = exactBinomialInterval(errors, bitsTested, ...
    1-cfg.confidenceLevel);
p.zeroErrorsObserved = errors == 0;
if p.zeroErrorsObserved
    p.zeroErrorOneSided95Upper = -expm1(log(1-cfg.confidenceLevel)/bitsTested);
end
p.noiseVarianceExpected = sigma2;
p.noiseSamplePowerMeasured = sampleNoiseEnergy / p.samples;
p.noiseSamplePowerRatio = p.noiseSamplePowerMeasured / sigma2;
p.noiseProjectionVarianceExpected = sigma2 / cfg.samplesPerBit;
p.noiseProjectionPowersMeasured = (projectedNoiseEnergy/bitsTested).';
p.noiseProjectionPowerRatios = p.noiseProjectionPowersMeasured / ...
    p.noiseProjectionVarianceExpected;
p.noiseProjectionCorrelationMagnitude = abs(projectedNoiseCross) / ...
    sqrt(prod(projectedNoiseEnergy));
p.maxSignalPowerAbsError = maxSignalPowerAbsError;
p.firCorrelationMaxAbsError = firError;
p.phaseEnergyMaxRelativeError = phaseEnergyError;
p.phaseDecisionDifferences = phaseDecisionDifferences;
if offsetHz == 0
    p.theoryApplicable = true;
    p.zeroOffsetTheoreticalBer = 0.5 * exp(-gamma/2);
    alphaPerPoint = (1-cfg.theoryFamilyConfidenceLevel) / numel(cfg.ebNoDb);
    [p.theoryFamilywiseLower,p.theoryFamilywiseUpper] = ...
        exactBinomialInterval(errors,bitsTested,alphaPerPoint);
    p.theoryWithinFamilywiseInterval = p.zeroOffsetTheoreticalBer >= ...
        p.theoryFamilywiseLower && p.zeroOffsetTheoreticalBer <= ...
        p.theoryFamilywiseUpper;
    p.theoryErrorCountZScore = (errors - bitsTested*p.zeroOffsetTheoreticalBer) / ...
        sqrt(bitsTested*p.zeroOffsetTheoreticalBer*(1-p.zeroOffsetTheoreticalBer));
end
p.elapsedSeconds = toc(pointTimer);
end

function p = pointTemplate()
% NaN theoretical fields become JSON null for nonzero-offset points.
p = struct('ebNoDb',NaN,'frequencyOffsetHz',NaN,'seed',NaN, ...
    'errors',0,'bits',0,'samples',0,'berEstimate',NaN, ...
    'ci95Lower',NaN,'ci95Upper',NaN,'zeroErrorsObserved',false, ...
    'zeroErrorOneSided95Upper',NaN, ...
    'noiseVarianceExpected',NaN,'noiseSamplePowerMeasured',NaN, ...
    'noiseSamplePowerRatio',NaN,'noiseProjectionVarianceExpected',NaN, ...
    'noiseProjectionPowersMeasured',[NaN NaN], ...
    'noiseProjectionPowerRatios',[NaN NaN], ...
    'noiseProjectionCorrelationMagnitude',NaN, ...
    'maxSignalPowerAbsError',NaN,'firCorrelationMaxAbsError',NaN, ...
    'phaseEnergyMaxRelativeError',NaN,'phaseDecisionDifferences',0, ...
    'theoryApplicable',false,'zeroOffsetTheoreticalBer',NaN,'theoryFamilywiseLower',NaN, ...
    'theoryFamilywiseUpper',NaN,'theoryWithinFamilywiseInterval',false, ...
    'theoryErrorCountZScore',NaN,'elapsedSeconds',NaN);
end

function [lo,hi] = exactBinomialInterval(errors,trials,alpha)
% Clopper-Pearson interval using betaincinv from base MATLAB, no binofit.
if errors == 0
    lo = 0;
    hi = -expm1(log(alpha/2)/trials);
elseif errors == trials
    lo = exp(log(alpha/2)/trials);
    hi = 1;
else
    lo = betaincinv(alpha/2,errors,trials-errors+1);
    hi = betaincinv(1-alpha/2,errors+1,trials-errors);
end
end

function saveEvidence(result)
save(result.artifacts.mat,'result','-v7');
jsonText = jsonencode(result,'PrettyPrint',true,'ConvertInfAndNaN',true);
fid = fopen(result.artifacts.json,'w','n','UTF-8');
assert(fid >= 0, 'FSKBenchmark:OutputError', 'Cannot open benchmark JSON output.');
fileCleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonText);
end

function renderFigure(result)
cfg = result.parameters;
points = result.points;
baseline = points([points.frequencyOffsetHz] == 0);
fig = figure('Visible','off','Color','w','Position',[100 100 1500 480]);
figureCleanup = onCleanup(@() close(fig)); %#ok<NASGU>
layout = tiledlayout(fig,1,3,'Padding','compact','TileSpacing','compact');
title(layout,'Known-timing noncoherent orthogonal 2FSK | actual waveform Monte Carlo');
subtitle(layout,['100 ksample/s, 1 kbit/s, 8/12 kHz; ' ...
    '100000 bits per point; no PLL, packet acquisition, or RF']);

ax1 = nexttile(layout);
hold(ax1,'on');
fineEb = linspace(min(cfg.ebNoDb),max(cfg.ebNoDb),301);
hTheory = semilogy(ax1,fineEb,0.5*exp(-10.^(fineEb/10)/2),'k-', ...
    'LineWidth',1.5);
hMeasured = plotBerWithIntervals(ax1,baseline,[0 0.35 0.8]);
set(ax1,'YScale','log');
grid(ax1,'on');
xlabel(ax1,'E_b/N_0 (dB)'); ylabel(ax1,'Bit error probability / estimate');
title(ax1,'Zero frequency offset');
legend(ax1,[hTheory hMeasured],{'Theory','Measured, pointwise 95% CI'}, ...
    'Location','southwest');
ylim(ax1,[1e-5 0.6]);

ax2 = nexttile(layout);
hold(ax2,'on');
colors = lines(numel(cfg.frequencyOffsetsHz));
seriesHandles = gobjects(1,numel(cfg.frequencyOffsetsHz));
seriesLabels = cell(1,numel(cfg.frequencyOffsetsHz));
for offsetIndex = 1:numel(cfg.frequencyOffsetsHz)
    offsetHz = cfg.frequencyOffsetsHz(offsetIndex);
    selected = points([points.frequencyOffsetHz] == offsetHz);
    seriesHandles(offsetIndex) = plotBerWithIntervals(ax2,selected,colors(offsetIndex,:));
    seriesLabels{offsetIndex} = sprintf('%g Hz',offsetHz);
end
set(ax2,'YScale','log');
grid(ax2,'on');
xlabel(ax2,'E_b/N_0 (dB)'); ylabel(ax2,'BER with pointwise 95% CI');
title(ax2,'Fixed RX tones: frequency-offset sensitivity');
legend(ax2,seriesHandles,seriesLabels,'Location','southwest');
ylim(ax2,[1e-5 0.6]);

ax3 = nexttile(layout);
hold(ax3,'on');
projectionRatios = vertcat(baseline.noiseProjectionPowerRatios);
plot(ax3,cfg.ebNoDb,[baseline.noiseSamplePowerRatio],'-o','LineWidth',1.2);
plot(ax3,cfg.ebNoDb,projectionRatios(:,1),'-s','LineWidth',1.2);
plot(ax3,cfg.ebNoDb,projectionRatios(:,2),'-^','LineWidth',1.2);
yline(ax3,1,'k:');
grid(ax3,'on');
xlabel(ax3,'E_b/N_0 (dB)'); ylabel(ax3,'Measured / expected noise power');
title(ax3,'Noise-scale checks (zero offset)');
legend(ax3,{'Sample noise','8 kHz correlation','12 kHz correlation'}, ...
    'Location','best');
ylim(ax3,[0.97 1.03]);
exportgraphics(fig,result.artifacts.performancePng,'Resolution',160);
end

function handle = plotBerWithIntervals(ax,points,color)
x = [points.ebNoDb];
y = [points.berEstimate];
lo = [points.ci95Lower];
hi = [points.ci95Upper];
positive = y > 0;
% Zero observations have no finite log-axis point estimate. Plot their
% positive confidence bound with a downward marker instead of plotting 0.
plotY = y;
plotY(~positive) = NaN;
handle = errorbar(ax,x,plotY,y-lo,hi-y,'o-', ...
    'Color',color,'LineWidth',1.1,'MarkerSize',4,'CapSize',5);
if any(~positive)
    plot(ax,x(~positive),hi(~positive),'v','Color',color, ...
        'MarkerFaceColor',color,'MarkerSize',6,'HandleVisibility','off');
    text(ax,x(~positive),hi(~positive)*1.25, ...
        repmat({'0 errors: 95% CI upper'},1,nnz(~positive)), ...
        'FontSize',7,'Color',color);
end
end

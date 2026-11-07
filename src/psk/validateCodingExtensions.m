function result=validateCodingExtensions(outputDir)
% Reproducible coding/line-code evidence, independent of packet synchronization.
% All decoded bits enter BER, including codewords flagged as double errors.
% Uncoded BPSK amplitude 1; rate-1/2 SECDED amplitude sqrt(1/2): equal Eb=1.
if nargin<1,outputDir=fullfile(pwd,'coding_validation');end
if ~isfolder(outputDir),mkdir(outputDir);end
seed=20261025;stream=RandStream('mt19937ar','Seed',seed);
informationBits=40000;ebNoDb=0:2:8;codeRate=0.5;
rows=struct([]);
for k=1:numel(ebNoDb)
    data=double(randi(stream,[0 1],informationBits,1));
    encoded=advHammingEncode(data);ebNo=10^(ebNoDb(k)/10);
    sigma=sqrt(1/(2*ebNo));uncodedAmplitude=1;codedAmplitude=sqrt(codeRate);
    uncodedRx=uncodedAmplitude*(1-2*data)+sigma*randn(stream,numel(data),1);
    codedRx=codedAmplitude*(1-2*encoded)+sigma*randn(stream,numel(encoded),1);
    uncodedBits=double(uncodedRx<0);codedHardBits=double(codedRx<0);
    [decoded,stats]=advHammingDecode(codedHardBits);
    uncodedErrors=sum(uncodedBits~=data);codedErrors=sum(decoded~=data);
    assert(numel(decoded)==informationBits,'ADV:BERLength','Every information bit must enter BER.');
    row=struct('ebNoDb',ebNoDb(k),'informationBits',informationBits, ...
        'codeRate',codeRate,'uncodedAmplitude',uncodedAmplitude,'codedAmplitude',codedAmplitude, ...
        'noiseSigma',sigma,'uncodedEnergyPerInformationBit',uncodedAmplitude^2, ...
        'codedEnergyPerInformationBit',codedAmplitude^2/codeRate, ...
        'uncodedTransmittedSymbols',numel(data),'codedTransmittedSymbols',numel(encoded), ...
        'uncodedComparedBits',numel(data),'codedComparedBits',numel(decoded),'codedDiscardedBits',0, ...
        'uncodedErrors',uncodedErrors,'codedErrors',codedErrors, ...
        'uncodedBer',uncodedErrors/informationBits,'codedBer',codedErrors/informationBits, ...
        'uncodedWilson95',wilson95(uncodedErrors,informationBits), ...
        'uncodedTheory',0.5*erfc(sqrt(ebNo)), ...
        'correctedCodewords',stats.correctedErrors,'detectedDoubleCodewords',stats.detectedDoubleErrors, ...
        'codewordCount',stats.codewordCount);
    if k==1,rows=row;else,rows(k)=row;end %#ok<AGROW>
end

% A 16-bit physical burst: two whole raw codewords, or 16 separate single errors.
burstData=double(randi(stream,[0 1],128,1));coded=advHammingEncode(burstData);
rawWire=coded;rawWire(1:16)=1-rawWire(1:16);
interleaved=advInterleave(coded,16);interleaved(1:16)=1-interleaved(1:16);
deinterleaved=advDeinterleave(interleaved,16,numel(coded));
[rawDecoded,rawStats]=advHammingDecode(rawWire);
[interleavedDecoded,interleavedStats]=advHammingDecode(deinterleaved);
rawErrorMatrix=reshape(rawWire~=coded,8,[]).';
interleavedErrorMatrix=reshape(deinterleaved~=coded,8,[]).';
burst=struct('physicalBurstBits',16,'physicalBurstStart',1,'interleaveDepth',16, ...
    'informationBits',numel(burstData),'codewordCount',numel(coded)/8, ...
    'uninterleavedErrorsPerCodeword',sum(rawErrorMatrix,2).', ...
    'interleavedErrorsPerCodeword',sum(interleavedErrorMatrix,2).', ...
    'uninterleavedDecodedErrors',sum(rawDecoded~=burstData), ...
    'interleavedDecodedErrors',sum(interleavedDecoded~=burstData), ...
    'uninterleavedCorrections',rawStats.correctedErrors, ...
    'interleavedCorrections',interleavedStats.correctedErrors, ...
    'uninterleavedDetectedDoubleCodewords',rawStats.detectedDoubleErrors, ...
    'interleavedDetectedDoubleCodewords',interleavedStats.detectedDoubleErrors);

% Equal chip rate and equal mean power; Manchester takes twice as many chips.
chipRate=8000;samplesPerChip=8;fs=chipRate*samplesPerChip;
lineData=double(randi(stream,[0 1],1024,1));
nrzChips=2*lineData-1;manchesterPair=[(2*lineData-1).';(1-2*lineData).'];
manchesterChips=manchesterPair(:);
nrzWave=repelem(nrzChips,samplesPerChip);manchesterWave=repelem(manchesterChips,samplesPerChip);
[frequency,nrzPsd]=welchEstimate(nrzWave,fs,2048);
[~,manchesterPsd]=welchEstimate(manchesterWave,fs,2048);
df=frequency(2)-frequency(1);
lineCode=struct('informationBits',numel(lineData),'chipRate',chipRate, ...
    'sampleRate',fs,'samplesPerChip',samplesPerChip,'nrzInformationRate',chipRate, ...
    'manchesterInformationRate',chipRate/2,'nrzChipCount',numel(nrzChips), ...
    'manchesterChipCount',numel(manchesterChips),'nrzDurationSeconds',numel(nrzWave)/fs, ...
    'manchesterDurationSeconds',numel(manchesterWave)/fs, ...
    'nrzMeanPower',mean(nrzWave.^2),'manchesterMeanPower',mean(manchesterWave.^2), ...
    'nrzPsdIntegratedPower',sum(nrzPsd)*df,'manchesterPsdIntegratedPower',sum(manchesterPsd)*df, ...
    'welchWindowSamples',2048,'welchOverlapSamples',1024, ...
    'frequencyHz',frequency.','nrzPsdPerHz',nrzPsd.','manchesterPsdPerHz',manchesterPsd.');

artifacts=struct('berPng',fullfile(outputDir,'fair_energy_bpsk_secded_ber.png'), ...
    'burstPng',fullfile(outputDir,'interleaver_16bit_burst.png'), ...
    'lineCodePng',fullfile(outputDir,'nrz_manchester_waveform_spectrum.png'), ...
    'json',fullfile(outputDir,'coding_extensions.json'));
drawBer(rows,artifacts.berPng);
drawBurst(rawErrorMatrix,interleavedErrorMatrix,burst,artifacts.burstPng);
drawLineCode(nrzWave,manchesterWave,frequency,nrzPsd,manchesterPsd,fs,artifacts.lineCodePng);
result=struct('seed',seed,'ber',rows,'burst',burst,'lineCode',lineCode,'artifacts',artifacts, ...
    'berScope','Known symbol timing, real AWGN BPSK, no carrier/timing/frame synchronization and no packet filtering.', ...
    'fairEnergyDefinition','Eb=1 for each information bit. A_uncoded=1; A_coded=sqrt(R), R=1/2; sigma=sqrt(1/(2*EbNo)).', ...
    'doubleErrorPolicy','All 40000 decoded information bits are compared, including detected-double-error codewords; no erasures or survivor selection.', ...
    'correctionCountMeaning','correctedCodewords counts decoder correction attempts; higher-weight errors may miscorrect.', ...
    'confidenceIntervalScope','95% Wilson intervals apply only to independent uncoded bits. Decoded bits within a Hamming codeword are dependent, so no independent-binomial interval is claimed for coded BER.', ...
    'zeroErrorPlotPolicy','If a point has zero errors, JSON BER remains zero; only its log-scale plot position is 0.5/N. Wilson confidence intervals are provided for uncoded bits only.', ...
    'lineCodeScope','Same 8000 chips/s and unit mean power. Manchester uses 2 chips/information bit, reducing information rate to 4000 bit/s.', ...
    'limitations','A short known-timing BER benchmark is not packet success probability, complete-link BER, physical soundcard testing or RF testing. SECDED does not guarantee an advantage at every Eb/N0.');
fid=fopen(artifacts.json,'w','n','UTF-8');assert(fid>=0,'ADV:EvidenceWrite','Cannot create JSON evidence.');
closer=onCleanup(@() fclose(fid));fwrite(fid,jsonencode(result,PrettyPrint=true),'char');clear closer
summary=struct2table(rows);
disp(summary(:,{'ebNoDb','informationBits','uncodedErrors','codedErrors', ...
    'uncodedBer','codedBer','detectedDoubleCodewords'}));
fprintf('Coding evidence written to %s\n',outputDir);
end

function interval=wilson95(errors,count)
z=1.95996398454005;p=errors/count;denominator=1+z^2/count;
center=(p+z^2/(2*count))/denominator;
radius=z*sqrt(p*(1-p)/count+z^2/(4*count^2))/denominator;
interval=[max(0,center-radius),min(1,center+radius)];
end

function [frequency,psd]=welchEstimate(wave,fs,windowLength)
% Explicit one-sided Welch PSD, normalized to power/Hz; no signal toolbox required.
step=windowLength/2;window=0.5-0.5*cos(2*pi*(0:windowLength-1).'/(windowLength-1));
starts=1:step:(numel(wave)-windowLength+1);psd=zeros(windowLength/2+1,1);
for start=starts
    transformed=fft(wave(start:start+windowLength-1).*window);
    block=abs(transformed(1:windowLength/2+1)).^2/(fs*sum(window.^2));
    block(2:end-1)=2*block(2:end-1);psd=psd+block;
end
psd=psd/numel(starts);frequency=(0:windowLength/2).'*fs/windowLength;
end

function drawBer(rows,path)
fig=figure('Visible','off','Color','w','Position',[100 100 1050 700]);
closer=onCleanup(@() close(fig));ax=axes(fig);hold(ax,'on');
x=[rows.ebNoDb];n=[rows.informationBits];
uncoded=[rows.uncodedBer];coded=[rows.codedBer];
uCi=vertcat(rows.uncodedWilson95);
uPlot=max(uncoded,0.5./n);cPlot=max(coded,0.5./n);
errorbar(ax,x,uPlot,uPlot-max(uCi(:,1).',1e-7),uCi(:,2).'-uPlot,'o-', ...
    'LineWidth',1.5,'MarkerSize',7,'DisplayName','Uncoded BPSK, observed + 95% Wilson CI');
plot(ax,x,cPlot,'s-', ...
    'LineWidth',1.5,'MarkerSize',7,'DisplayName','SECDED(8,4), all decoded information bits');
plot(ax,x,[rows.uncodedTheory],'k--','LineWidth',1.3,'DisplayName','Uncoded BPSK theory');
set(ax,'YScale','log','FontName','Arial','FontSize',11);grid(ax,'on');
xlabel(ax,'E_b/N_0 per INFORMATION bit (dB)');ylabel(ax,'Information-bit error rate');
title(ax,{'Equal information-bit energy: E_b = 1, rate R = 1/2', ...
    '40,000 information bits/point; known timing; detected double errors included'});
legend(ax,'Location','southwest');xlim(ax,[-0.3 8.3]);ylim(ax,[1e-6 0.5]);
if any(uncoded==0|coded==0)
    text(ax,0.98,0.04,'Zero-error points plotted at 0.5/N; uncoded confidence bounds retained', ...
        'Units','normalized','HorizontalAlignment','right','FontSize',9);
end
exportgraphics(fig,path,'Resolution',160);clear closer
end

function drawBurst(rawErrors,interleavedErrors,burst,path)
fig=figure('Visible','off','Color','w','Position',[100 100 1100 750]);
closer=onCleanup(@() close(fig));layout=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout);imagesc(ax,1:8,1:size(rawErrors,1),rawErrors);clim(ax,[0 1]);
xlabel(ax,'Bit position inside an 8-bit codeword');ylabel(ax,'Codeword index');
title(ax,sprintf('No interleaver: %d decoded information-bit errors',burst.uninterleavedDecodedErrors));
set(ax,'XTick',1:8,'FontName','Arial');
ax=nexttile(layout);imagesc(ax,1:8,1:size(interleavedErrors,1),interleavedErrors);clim(ax,[0 1]);
xlabel(ax,'Bit position inside an 8-bit codeword');ylabel(ax,'Codeword index');
title(ax,sprintf('Depth 16: %d corrected, %d residual errors',burst.interleavedCorrections,burst.interleavedDecodedErrors));
set(ax,'XTick',1:8,'FontName','Arial');colormap(fig,[0.94 0.96 0.98;0.82 0.16 0.10]);
bar=colorbar(ax);bar.Ticks=[0 1];bar.TickLabels={'No error','Corrupted bit'};
title(layout,{'Same 16 consecutive physical bit flips, before SECDED decoding', ...
    'Interleaving spreads the burst across 16 codewords; each has one correctable error'});
exportgraphics(fig,path,'Resolution',160);clear closer
end

function drawLineCode(nrz,manchester,f,nrzPsd,manchesterPsd,fs,path)
fig=figure('Visible','off','Color','w','Position',[100 100 1100 900]);
closer=onCleanup(@() close(fig));layout=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
shown=128;time=(0:shown).'/fs*1000;
ax=nexttile(layout);stairs(ax,time,[nrz(1:shown);nrz(shown)],'LineWidth',1.4);grid(ax,'on');
ylim(ax,[-1.3 1.3]);xlim(ax,[0 time(end)]);ylabel(ax,'NRZ level');
title(ax,'NRZ: 8,000 chips/s = 8,000 information bits/s');set(ax,'FontName','Arial');
ax=nexttile(layout);stairs(ax,time,[manchester(1:shown);manchester(shown)],'LineWidth',1.4);grid(ax,'on');
ylim(ax,[-1.3 1.3]);xlim(ax,[0 time(end)]);ylabel(ax,'Manchester level');xlabel(ax,'Time (ms)');
title(ax,'Manchester: 8,000 chips/s = 4,000 information bits/s');set(ax,'FontName','Arial');
ax=nexttile(layout);plot(ax,f/1000,10*log10(max(nrzPsd,1e-12)),'LineWidth',1.3);hold(ax,'on');
plot(ax,f/1000,10*log10(max(manchesterPsd,1e-12)),'LineWidth',1.3);grid(ax,'on');
xlim(ax,[0 16]);ylim(ax,[-100 -25]);xlabel(ax,'Frequency (kHz)');ylabel(ax,'PSD (dB / Hz)');
title(ax,'Welch spectra of actual sampled rectangular waveforms; same unit mean power');
legend(ax,{'NRZ','Manchester'},'Location','northeast');set(ax,'FontName','Arial');
title(layout,{'Same input bits, fixed chip rate: Manchester information rate is halved', ...
    '64 ksample/s; 1,024 information bits; 2,048-sample Hann window, 50% overlap'});
exportgraphics(fig,path,'Resolution',160);clear closer
end

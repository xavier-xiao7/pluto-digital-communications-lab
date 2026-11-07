function plots=nativeRxPlots(data,fs,startSeconds)
% One real block: at most 8192 FFT samples, 1024 peak-preserving spectrum bins.
data=double(data(:));N=min(8192,numel(data));
assert(N>=16,'NativeRx:Plot','Not enough actual samples for a spectrum.');
block=data(1:N);window=0.5-0.5*cos(2*pi*(0:N-1)'/N);
power=abs(fftshift(fft((block-mean(block)).*window))).^2/(fs*sum(window.^2));
frequency=(-floor(N/2):ceil(N/2)-1)'*fs/N;
edges=round(linspace(1,N+1,min(1024,N)+1));indices=zeros(numel(edges)-1,1);
for k=1:numel(indices)
    range=edges(k):edges(k+1)-1;[~,at]=max(power(range));indices(k)=range(at);
end
timeCount=min(numel(data),max(16,round(0.002*fs)));
timeIndices=unique(round(linspace(1,timeCount,min(512,timeCount))));
plots=struct('rfFrequencyHz',frequency(indices).','rfPowerDb',10*log10(max(power(indices),realmin)).', ...
    'timeSeconds',startSeconds+(timeIndices-1)/fs,'rxI',real(data(timeIndices)).');
end

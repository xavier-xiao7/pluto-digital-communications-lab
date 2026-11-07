function [base,tracking]=demoTrackCarrier(iq,seed)
% Track ONLY two public RF calibration tones. No message/nonce/TX truth.
% Independent Pluto oscillators can warm up appreciably during one capture.
fs=1e6;N=65536;hop=N/2;nfft=N;
w=.5-.5*cos(2*pi*(0:N-1)'/(N-1));f=(0:N-1)'*fs/N;
tones=[150e3 190e3];times=[];offsets=[];contrasts=[];
for first=1:hop:numel(iq)-N+1
 P=abs(fft(iq(first:first+N-1).*w,nfft)).^2;
 est=zeros(1,2);contrast=zeros(1,2);
 for j=1:2
  indices=find(abs(f-(tones(j)+seed))<3000);
  [peak,u]=max(P(indices));at=indices(u);
  v=log(max(P(at-1:at+1),realmin));den=v(1)-2*v(2)+v(3);
  delta=0;if abs(den)>eps,delta=max(-.5,min(.5,.5*(v(1)-v(3))/den));end
  est(j)=(at-1+delta)*fs/N-tones(j);
  contrast(j)=10*log10(max(peak,realmin)/max(median(P(indices)),realmin));
 end
 if min(contrast)>=12&&abs(diff(est))<=30
  times(end+1,1)=first+(N-1)/2;offsets(end+1,1)=mean(est);contrasts(end+1,1)=min(contrast); %#ok<AGROW>
 end
end
assert(numel(offsets)>=3,'DEMO:Carrier','有效校准音不足，无法跟踪载波。');
% Buffer wrapping can transiently broaden the tones; reject short impulses.
filtered=movmedian(offsets,5);
n=(0:numel(iq)-1)';cfo=interp1(times,filtered,n+1,'linear','extrap');
phase=(2*pi/fs)*cumsum(cfo);
base=iq.*exp(-1i*(2*pi*100e3*n/fs+phase));
% Keep a full window of lead-in and all tail samples: a short final partial
% FFT window still contains valid packet bits and must never be discarded.
firstSample=max(1,round(times(1)-(N-1)/2)-N);lastSample=numel(iq);
base=base(firstSample:lastSample);
tracking=struct('samplePositions',times,'rawCfoHz',offsets,'trackedCfoHz',filtered, ...
 'contrastDb',contrasts,'startCfoHz',filtered(1),'endCfoHz',filtered(end), ...
 'rangeHz',max(filtered)-min(filtered),'firstSample',firstSample,'lastSample',lastSample,'publicCalibrationOnly',true);
end

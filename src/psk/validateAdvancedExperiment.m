function summary=validateAdvancedExperiment(destination)
% Multiple rounds with independent seeds, arbitrary byte payloads, and failures.
here=fileparts(mfilename('fullpath'));addpath(here,'-begin');
if nargin<1,destination=fullfile(fileparts(here),'验证');end
if ~isfolder(destination),mkdir(destination);end
media=createExtensionPayloads(fullfile(destination,'发送素材'));
cases=struct('name',{},'round',{},'bytes',{},'options',{},'required',{},'mediaName',{});
message=uint8('BPSK and QPSK digital communications test.').';
for modulation={'BPSK','QPSK'}
 for channel={'ideal','awgn','rician','combined'}
  cases(end+1)=caseOf([modulation{1} '_' channel{1}],1,message,struct('modulation',modulation{1},'channelMode',channel{1}),true,'');
 end
 for coding=1:3
  protocol=struct('fec',coding~=1,'interleave',coding==3,'lineCode','NRZ');
  if coding==3,protocol.lineCode='Manchester';end
  options=struct('modulation',modulation{1},'protocol',protocol);
  cases(end+1)=caseOf(sprintf('%s_coding_%d',modulation{1},coding),1,uint8((0:255).'),options,true,'');
 end
 cases(end+1)=caseOf([modulation{1} '_rectangular'],1,message,struct('modulation',modulation{1},'pulseShape','rectangular'),true,'');
 for j=1:numel(media)
  opts=struct('modulation',modulation{1},'protocol',struct('payloadType',media(j).payloadType));
  [~,stem,extension]=fileparts(media(j).path);
  cases(end+1)=caseOf([modulation{1} '_media_' num2str(j)],2,media(j).bytes,opts,true,[stem extension]);
 end
end
longText=uint8(repmat('Long message segment 0123456789 ABC xyz. ',1,130)).';
cases(end+1)=caseOf('QPSK_long_text',2,longText,struct('modulation','QPSK'),true,'long_text.txt');
% New payloads and seeds are different from the component-development tests.
stream=RandStream('mt19937ar','Seed',20261103);
lengths=[17 255 256 257 511 777];offsets=[-250 250 117 -219 39 0];
for m=1:2
 mode='BPSK';if m==2,mode='QPSK';end
 for j=1:numel(lengths)
  bytes=uint8(randi(stream,[0 255],lengths(j),1));
  opts=struct('modulation',mode,'awgnSeed',2100+31*j+m,'fadingSeed',3100+17*j+m, ...
   'leadSamples',randi(stream,[1 901]),'frequencyOffsetHz',offsets(j),'phaseOffsetRad',2*pi*rand(stream), ...
   'protocol',struct('repetitions',2,'payloadType',2));
  if mod(j,2)==0,opts.protocol.lineCode='Manchester';end
  cases(end+1)=caseOf(sprintf('%s_independent_%d',mode,j),3,bytes,opts,true,'');
 end
end
for m=1:2
 mode='BPSK';if m==2,mode='QPSK';end
 for eb=[0 4 8 12 16]
  for seed=[401 503]
   opts=struct('modulation',mode,'ebNo',eb,'awgnSeed',seed,'fadingSeed',seed+7,'protocol',struct('repetitions',1));
   cases(end+1)=caseOf(sprintf('%s_stress_EbNo%d_seed%d',mode,eb,seed),4,message,opts,false,'');
  end
 end
 opts=struct('modulation',mode,'frequencyOffsetHz',700,'protocol',struct('repetitions',1));
 cases(end+1)=caseOf([mode '_stress_CFO700'],4,message,opts,false,'');
end
rows=struct([]);snapshots=struct();
for k=1:numel(cases)
 item=cases(k);fprintf('ADVANCED_CASE %d/%d %s\n',k,numel(cases),item.name);
 rec=struct('name',item.name,'round',item.round,'required',item.required,'complete',false,'equalBytes',false, ...
  'hashEqual',false,'bytes',numel(item.bytes),'validFrames',0,'expectedFrameCopies',0,'correctedErrors',0, ...
  'tiles',0,'sourceTiles',0,'repetitions',0,'transmissionSeconds',0,'payloadRateBitsPerSecond',0,'options',item.options,'coarseCfoHz',NaN,'estimatedClockPpm',NaN,'noiseVarianceRelativeError',NaN,'error','');
 try
  [o,r,c,t]=runAdvancedExperiment(item.bytes,item.options);
  rec.complete=r.complete;rec.equalBytes=r.complete&&isequal(r.bytes,item.bytes);
  [~,hash]=advSha256(r.bytes);rec.hashEqual=r.complete&&strcmp(hash,t.sha256Hex);
  rec.repetitions=c.protocol.repetitions;rec.transmissionSeconds=t.sampleCount/c.Fs;rec.payloadRateBitsPerSecond=numel(item.bytes)*8/rec.transmissionSeconds;
  rec.validFrames=r.validFrameCount;rec.expectedFrameCopies=t.expectedCopies;rec.correctedErrors=r.correctedErrors;
  rec.tiles=numel(r.tiles);rec.sourceTiles=t.phy.tileCount;rec.coarseCfoHz=r.coarseCfoHz;rec.estimatedClockPpm=r.estimatedClockPpm;
  if ismember(c.channelMode,{'awgn','combined'})
   variance=mean(abs(o.awgnSignal.Data(:)-o.txSignal.Data(:)).^2);expected=c.sps/c.bitsPerSymbol/10^(c.ebNo/10);
   rec.noiseVarianceRelativeError=abs(variance/expected-1);assert(rec.noiseVarianceRelativeError<0.03,'Noise scale check failed.');
  end
  assert(numel(o.rxWave.Data)==t.sampleCount,'Sample count mismatch.');
  if ~isempty(item.mediaName)&&rec.equalBytes&&rec.hashEqual
   folder=fullfile(destination,'恢复文件',c.modulation);if ~isfolder(folder),mkdir(folder);end
   restored=fullfile(folder,item.mediaName);fid=fopen(restored,'wb');fwrite(fid,r.bytes,'uint8');fclose(fid);
   fid=fopen(restored,'rb');diskBytes=fread(fid,Inf,'*uint8');fclose(fid);assert(isequal(diskBytes,item.bytes));
   [~,~,ext]=fileparts(restored);if strcmpi(ext,'.png'),pixels=imread(restored);assert(~isempty(pixels));elseif strcmpi(ext,'.wav'),[audio,fs]=audioread(restored);assert(~isempty(audio)&&fs==8000);end
  end
  if strcmp(item.name,'BPSK_combined')||strcmp(item.name,'QPSK_combined')||contains(item.name,'rectangular')
   snapshots.(item.name)=struct('out',o,'rx',r,'cfg',c,'truth',t);
  end
  if item.round==2
   save(fullfile(destination,[item.name '_receipt.mat']),'c','r','t','rec','-v7');
  end
 catch e
  rec.complete=false;rec.equalBytes=false;rec.hashEqual=false;rec.error=getReport(e,'extended','hyperlinks','off');fprintf('%s\n',rec.error);
 end
 if isempty(rows),rows=rec;else,rows(end+1)=rec;end %#ok<AGROW>
 fprintf('ADVANCED_RESULT %s complete=%d hash=%d valid=%d/%d corrected=%d\n',rec.name,rec.complete,rec.hashEqual,rec.validFrames,rec.expectedFrameCopies,rec.correctedErrors);
 writeJson(fullfile(destination,'advanced_cases.json'),rows);
end
summary=struct('version',version,'caseCount',numel(rows),'requiredCount',sum([rows.required]), ...
 'requiredPassed',all([rows([rows.required]).equalBytes]&[rows([rows.required]).hashEqual]), ...
 'completeCount',sum([rows.equalBytes]),'softwareErrorCount',sum(~cellfun(@isempty,{rows.error})), ...
 'failedCases',{{rows(~[rows.equalBytes]).name}},'rfTested',false,'soundcardPhysicalTested',false);
writeJson(fullfile(destination,'advanced_summary.json'),summary);
save(fullfile(destination,'advanced_snapshots.mat'),'snapshots','-v7');
assert(summary.requiredPassed&&summary.softwareErrorCount==0,'Required advanced cases failed; failures retained in JSON.');
end
function c=caseOf(name,round,bytes,options,required,mediaName)
c=struct('name',name,'round',round,'bytes',bytes(:),'options',options,'required',required,'mediaName',mediaName);
end
function writeJson(file,data)
fid=fopen(file,'w','n','UTF-8');guard=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(data,PrettyPrint=true),'char');
end

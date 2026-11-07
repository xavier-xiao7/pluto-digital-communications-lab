function [wave,meta]=demoMakeWave(data,mode,kind,name,trace)
demoInit();mode=upper(char(mode));
if nargin<5,trace=[];end
if nargin<3,kind='text';end
if nargin<4,name='message.txt';end
data=uint8(data(:));
if ~isempty(trace)
 trace.add('01 内容变字节',{sprintf('%s / %d字节。文字按UTF-8编码；图片直接读取文件字节。',name,numel(data));'图中每个柱子是一字节；下面展示这些字节的二进制表示。'}, ...
  {DemoTrace.bytes(data,'原始内容字节'),DemoTrace.bits(advBytesToBits(data),'原始内容的比特')});
end
if strcmp(mode,'2FSK')
    assert(strcmp(kind,'text')&&numel(data)<=48,'DEMO:FSKSize','2FSK基准限48字节文本；文件请选择QPSK或BPSK。');
    meta=struct('nonce',NativeUINonce(),'kind','text','name','message.txt','bytes',numel(data));
    [~,meta.sha256]=advSha256(data);
    [wave,physical]=plutoFskMakeWave(['~NATIVE1~' meta.nonce '~' native2unicode(data.','UTF-8')],struct('txGainDb',-20,'txAmplitude',.25));
    meta.mode=mode;meta.bufferSeconds=physical.bufferSeconds;meta.sampleRate=1e6;meta.frameCount=physical.frameCount;
    if ~isempty(trace)
     oldPath=path;pathGuard=onCleanup(@()path(oldPath));addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'fskCore'));
     cfg=fskConfig();[bits,truth]=fskEncodeText(physical.wireMessage,cfg);
     trace.add('02 FSK封装与比特',{sprintf('独立无线标记 %s；帧数%d。',meta.nonce,truth.frameCount);'下图来自同一封装线上文字的编码；高低电平决定8/12kHz两种频率。'}, ...
      {DemoTrace.bytes(uint8(physical.wireMessage),'线上封装文字字节'),DemoTrace.bits(bits(1:cfg.sps:end),'发送码元比特')});
     trace.add('03 FSK射频数字波形',{'100kHz波形真实插值到1MHz，再搬移到100kHz数字中频。';'下图是交给Pluto的数字IQ；天线实际发射由接收端采样验证。'},DemoTrace.signal(wave,1e6,'发送缓冲'));
    end
    return
end
[packet,meta]=demoEnvelope('pack',data,kind,name);cfg=advPskConfig(mode);
[~,protocol]=advEncodeBytes(packet,advProtocolConfig());
if ~isempty(trace)
 trace.add('02 分片与帧封装',{sprintf('无线标记 %s；封装%d字节，分成%d片。',meta.nonce,numel(packet),protocol.frameCount);'每片带编号、总片数、长度、SHA标识和CRC；帧头保护后再加入同步字。'}, ...
  {DemoTrace.bytes(protocol.headers{1},'第一片帧头字节（含帧头CRC）'),DemoTrace.plot('bar','各帧编码后位数',1:numel(protocol.frames),cellfun(@numel,protocol.frames),'帧序号','比特数')});
 pc=advProtocolConfig();firstPayload=packet(1:min(256,end));c=advCrc16([protocol.headers{1}(1:51);firstPayload]);
 raw=advBytesToBits([firstPayload;uint8(floor(double(c)/256));uint8(mod(double(c),256))]);
 body=protocol.frames{1}(protocol.bodyBitStarts(1):end-pc.guardBits);
 trace.add('03 纠错编码与交织',{'SECDED纠错编码加入校验位，交织重新排列位置，让连续损伤分散。';'上图是第一片载荷和CRC的原始比特；下图是实际进入发送帧的纠错、交织后比特。'}, ...
  {DemoTrace.bits(raw,'纠错前：载荷与CRC'),DemoTrace.bits(body,'纠错、交织后：实际帧体')});
end
[ib,qb,gate,tiles]=advPskFrameBits(protocol.frames,cfg);
symbols=((1-2*ib)+1i*cfg.qGain*(1-2*qb))*cfg.symbolNormalization.*gate;
if ~isempty(trace)
 trace.add('04 比特映射成码元',{sprintf('%s每码元%d比特，%d组公共PN训练与数据块。',mode,cfg.bitsPerSymbol,tiles.tileCount);'星座是发送码元的I/Q取值。第二图显示训练和数据共同组成的实际码元序列。'}, ...
  {DemoTrace.constellation(symbols(gate>0),'成形前发送星座'),DemoTrace.plot('line','实际I/Q码元序列',0:min(255,numel(symbols)-1),[real(symbols(1:min(256,end))) imag(symbols(1:min(256,end)))],'码元序号','码元幅度')});
end
h=rcosdesign(cfg.rolloff,cfg.filterSpan,cfg.sps,'sqrt').';
base=upfirdn(symbols,h*sqrt(cfg.sps),cfg.sps,1);
if ~isempty(trace)
 trace.add('05 RRC脉冲成形',{'根升余弦滤波平滑码元跳变、限制带宽。采样率48kHz，码元速率3kbaud，滚降0.5。';'眼图叠加实际成形波形的多个两码元窗口，起点为发送缓冲起点。'}, ...
  {DemoTrace.spectrum(base,cfg.Fs,'成形后的基带频谱'),DemoTrace.eye(base,cfg.sps,'发送成形波形叠加 / I路')});
end
radio=resample(base,125,6,32,8.6);n=(0:numel(radio)-1).';
radio=radio/max(abs(radio));
% Two public calibration tones are part of the transmitted waveform. They
% acquire independent-radio CFO before the original narrow PSK synchronizer.
wave=.18*radio.*exp(1i*2*pi*100e3*n/1e6)+.035*exp(1i*2*pi*150e3*n/1e6)+.035*exp(1i*2*pi*190e3*n/1e6);
wave=complex(single(.25*wave/max(abs(wave))));
assert(numel(wave)<=16777216,'DEMO:Buffer','波形超过Pluto循环缓冲，请缩小载荷。');
meta.mode=mode;meta.sampleRate=1e6;meta.bufferSeconds=numel(wave)/1e6;
meta.frameCount=protocol.frameCount;meta.tiles=tiles.tileCount;
meta.symbolRate=cfg.symbolRate;meta.rrcRolloff=cfg.rolloff;
meta.calibrationHz=[150e3 190e3];meta.digitalIfHz=100e3;
if ~isempty(trace)
 trace.add('06 变采样与数字中频',{sprintf('48kHz → 1MHz；%d个IQ样本，缓冲%.3f秒。',numel(wave),meta.bufferSeconds);'数据搬到100kHz，公共校准音位于150/190kHz。两端接收机用它们估计频率偏差。'},DemoTrace.signal(wave,1e6,'实际交给Pluto的IQ'));
end
end

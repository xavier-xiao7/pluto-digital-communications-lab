function demoTraceFsk(trace,e)
% Observe the existing FSK receiver's public diagnostic callback only.
switch e.stage
 case 'frequency'
  trace.add('02 FSK双音捕获',{e.detail}, ...
   {DemoTrace.plot('line','实际双音捕获频谱',e.plots.rfFrequencyHz/1000,e.plots.rfPowerDb,'频率 / kHz','谱功率 / dB')});
 case 'baseband'
  % This callback exposes counts only; do not invent a waveform here.
 case 'demod'
  trace.add('03 双音匹配能量判决',{e.detail;'判决量为(E1−E0)/(E1+E0)，正负对应两种频率。此前已完成去中频、去频偏及10倍抽取。'}, ...
   {DemoTrace.plot('line','实际软判决波形',e.plots.softTimeSeconds,e.plots.soft,'时间 / s','归一化能量差')});
 case 'timing_crc'
  trace.add('04 定时采样与CRC',{e.detail}, ...
   {DemoTrace.plot('stairs','实际定时采样判决',e.plots.decisionTimeSeconds,e.plots.decisionBits,'时间 / s','比特'),DemoTrace.plot('bar','同步候选 / CRC有效 / CRC拒绝',1:3,[e.result.syncCandidates e.result.validFrameCopies e.result.crcRejected],'类别 1 / 2 / 3','次数')});
 case 'text'
  b=unicode2native(e.result.message,'UTF-8');trace.add('05 FSK文字恢复',{e.detail;'这里是接收封装文字；主窗口随后取出无线标记和用户内容。'}, ...
   {DemoTrace.bytes(b,'实际恢复封装文字字节'),DemoTrace.bits(advBytesToBits(uint8(b(:))),'实际恢复封装比特')});
end
end

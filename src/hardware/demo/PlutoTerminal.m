classdef PlutoTerminal < handle
 properties
  Figure; Mode; Input; Scene; Role; TxGain; Status; Received; Info; Log; Ax; Buttons;
  Hint; InputLabel; ResultLabel; ImagePreview; Trace; ProcessButton;
  Serial; OutputRoot; Busy=false; Stop=false; Closing=false; Preview=false;
  Radio=[]; RunFolder=''; Events={}; FileBytes=uint8([]); FileName=''; ReceivedFile=''; LastResult=struct();
 end
 methods
  function app=PlutoTerminal(role,visible,preview)
   demoInit();if nargin<1,role='RX';end;if nargin<2,visible='on';end;if nargin<3,preview=false;end
   app.Preview=preview;app.Trace=DemoTrace();host='DIGITAL COMMUNICATIONS LAB';app.Serial='待本机USB识别';
   app.OutputRoot=getenv('PLUTO_LAB_OUTPUT_DIR');
   if isempty(app.OutputRoot)
    repo=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    app.OutputRoot=fullfile(repo,'results','hardware');
   end
   dark=[.035 .055 .075];panel=[.065 .09 .115];ink=[.82 .89 .90];accent=[.20 .88 .72];
   app.Figure=uifigure('Name',['PLUTO / ' role ' / 本机独立无线终端'],'Position',[50 50 1120 790], ...
    'Visible',visible,'Color',dark,'CloseRequestFcn',@(~,~)app.close());
   g=uigridlayout(app.Figure,[13 2],'RowHeight',{28,32,28,20,50,28,34,'1x',22,88,26,28,70}, ...
    'ColumnWidth',{'1x','1x'},'RowSpacing',5,'BackgroundColor',dark,'Padding',[16 10 16 10]);
   top=uigridlayout(g,[1 2],'ColumnWidth',{'1x',210},'BackgroundColor',dark,'Padding',0);top.Layout.Column=[1 2];
   heading=uilabel(top,'Text',['PLUTO // ' host '  ·  无线收发'],'FontSize',19,'FontWeight','bold','FontColor',accent);
   app.ProcessButton=uibutton(top,'Text','查看全过程（分步图解）','BackgroundColor',panel,'FontColor',accent,'FontWeight','bold','ButtonPushedFcn',@(~,~)app.Trace.show());
   app.Hint=uilabel(g,'Text','','FontSize',14,'FontWeight','bold','FontColor',ink);app.Hint.Layout.Column=[1 2];
   setup=uigridlayout(g,[1 6],'ColumnWidth',{75,90,70,'1x',80,100},'Padding',0,'BackgroundColor',dark);setup.Layout.Column=[1 2];
   uilabel(setup,'Text','本机用途','FontColor',ink);
   app.Role=uidropdown(setup,'Items',{'发送端','接收端'},'ItemsData',{'TX','RX'},'Value',role,'ValueChangedFcn',@(~,~)app.roles());
   uilabel(setup,'Text','波形','FontColor',ink);
   app.Mode=uidropdown(setup,'Items',{'QPSK','BPSK','2FSK'},'Value','QPSK');
   uilabel(setup,'Text','发射增益dB','FontColor',ink);
   app.TxGain=uidropdown(setup,'Items',{'-30','-20','-10','0'},'Value','-10');
   app.InputLabel=uilabel(g,'Text','要发送的文字 / 数字：点下面的框输入，例如 123.45','FontColor',ink);app.InputLabel.Layout.Column=[1 2];
   app.Input=uitextarea(g,'Value',{''},'ValueChangedFcn',@(~,~)app.typedText(),'BackgroundColor',panel,'FontColor',ink,'FontName','Consolas','FontSize',15);app.Input.Layout.Column=[1 2];
   app.Scene=uieditfield(g,'text','Value','场景待填写：距离 / 墙数 / 摆位 / 录像编号','BackgroundColor',panel,'FontColor',ink);app.Scene.Layout.Column=[1 2];
   actions=uigridlayout(g,[1 8],'ColumnWidth',repmat({'1x'},1,8),'BackgroundColor',dark,'Padding',0);actions.Layout.Column=[1 2];
   app.Buttons=gobjects(1,8);
   app.Buttons(1)=uibutton(actions,'Text','发送内容','ButtonPushedFcn',@(~,~)app.runAction('TX'));
   app.Buttons(2)=uibutton(actions,'Text','开始接收','ButtonPushedFcn',@(~,~)app.runAction('RX'));
   app.Buttons(3)=uibutton(actions,'Text','选择图片 / 文件','ButtonPushedFcn',@(~,~)app.chooseFile());
   app.Buttons(4)=uibutton(actions,'Text','改发文字','ButtonPushedFcn',@(~,~)app.clearFile());
   app.Buttons(5)=uibutton(actions,'Text','停止','ButtonPushedFcn',@(~,~)app.stop());
   app.Buttons(6)=uibutton(actions,'Text','使用示例图片','ButtonPushedFcn',@(~,~)app.useSampleImage());
   app.Buttons(7)=uibutton(actions,'Text','打开接收文件','ButtonPushedFcn',@(~,~)app.openReceived());
   app.Buttons(8)=uibutton(actions,'Text','上次接收','ButtonPushedFcn',@(~,~)app.restoreLastReceive());
   columns=[3 4 1 6 8 2 5 7];
   for k=1:8,app.Buttons(k).Layout.Column=columns(k);app.Buttons(k).BackgroundColor=panel;app.Buttons(k).FontColor=accent;end
   charts=uigridlayout(g,[1 2],'BackgroundColor',dark,'Padding',0);charts.Layout.Column=[1 2];
   app.Ax=gobjects(1,2);
   for k=1:2
    app.Ax(k)=uiaxes(charts,'Color',panel,'XColor',ink,'YColor',ink,'GridColor',[.25 .38 .40]);grid(app.Ax(k),'on');
   end
   title(app.Ax(1),'本机 IQ 频谱');xlabel(app.Ax(1),'基带频率 / kHz');ylabel(app.Ax(1),'相对谱功率 / dB');
   title(app.Ax(2),'接收同步后的星座 / FSK时域');
   for k=1:2,app.Ax(k).Title.Color=ink;end
   app.ResultLabel=uilabel(g,'Text','接收结果：尚未开始接收','FontSize',15,'FontWeight','bold','FontColor',accent);app.ResultLabel.Layout.Column=[1 2];
   resultGrid=uigridlayout(g,[1 2],'ColumnWidth',{'3x','1x'},'BackgroundColor',dark,'Padding',0);resultGrid.Layout.Column=[1 2];
   app.Received=uitextarea(resultGrid,'Editable','off','Value',{'收到的文字会显示在这里；收到的PNG会在右边显示。'},'BackgroundColor',panel,'FontColor',ink,'FontSize',14);
   app.ImagePreview=uiimage(resultGrid,'Visible','off','ScaleMethod','fit');
   app.Info=uilabel(g,'Text',['USB sn:' app.Serial '   |   RF 2.405 GHz / Fs 1 MHz'],'FontColor',ink,'FontName','Consolas');app.Info.Layout.Column=[1 2];
   app.Status=uilabel(g,'Text','待机 · 先填内容，再点击对应按钮','FontColor',accent,'FontSize',14,'FontWeight','bold');app.Status.Layout.Column=[1 2];
   app.Log=uitextarea(g,'Editable','off','Value',{'操作顺序：对方先点“开始接收”，本机随后点“发送内容”。'},'BackgroundColor',panel,'FontColor',ink,'FontName','Consolas');app.Log.Layout.Column=[1 2];
   if preview,app.Status.Text='OFFLINE PREVIEW · 离线界面检查 / 射频按钮禁用';end
   app.Trace.Progress=@(stage,detail)app.event(stage,detail);
   app.roles();if ~preview,app.restoreLastReceive();end
  end
  function roles(app)
   if app.Busy,return;end
   isTx=strcmp(app.Role.Value,'TX');
   if isTx,localRole='发送端';else,localRole='接收端';end
   app.Figure.Name=['PLUTO / ' localRole ' / 本机无线终端'];
   local='本机';remote='对端';
   if isTx,app.Hint.Text=[local '发送 → ' remote '接收：先在' remote '点“开始接收”，再在这里点“发送内容”。'];
   else,app.Hint.Text=[remote '发送 → ' local '接收：先在这里点“开始接收”，再去' remote '点“发送内容”。'];end
   for k=[1 2 3 4 6 8],app.Buttons(k).Enable='on';end
   app.Buttons(1).Enable=app.onoff(~app.Preview);app.Buttons(2).Enable=app.onoff(~app.Preview);app.Buttons(5).Enable='off';
   app.Buttons(7).Enable=app.onoff(~isempty(app.ReceivedFile)&&isfile(app.ReceivedFile));
   app.Input.Editable='on';app.Mode.Enable='on';app.Role.Enable='on';app.Scene.Enable='on';
   app.TxGain.Enable=app.onoff(isTx);
  end
  function chooseFile(app)
   [name,folder]=uigetfile({'*.png;*.txt;*.wav','测试图片或小文件';'*.*','所有文件'},'选择要发送的文件',app.samplesRoot());if isequal(name,0),return;end
   app.loadFile(fullfile(folder,name));
  end
  function folder=samplesRoot(app) %#ok<MANU>
   folder=fullfile(fileparts(mfilename('fullpath')),'test_images');
  end
  function useSampleImage(app),app.loadFile(fullfile(app.samplesRoot(),'01_test_A.png'));end
  function loadFile(app,file)
   entry=dir(file);if isempty(entry),uialert(app.Figure,'没有找到测试图片包。','文件未找到');return;end
   if entry.bytes>1024,uialert(app.Figure,'本版上限1024字节。请先点击“使用示例图片”，普通大照片暂不能直接传。','图片过大');return;end
   fid=fopen(file,'rb');guard=onCleanup(@()fclose(fid));app.FileBytes=fread(fid,Inf,'*uint8');app.FileName=entry.name;
   app.Mode.Value='QPSK';app.TxGain.Value='0';app.Role.Value='TX';app.roles();
   app.Input.Value={sprintf('已选：%s（%d字节）',entry.name,numel(app.FileBytes))};
   app.InputLabel.Text='图片已选好：直接点“发送内容”；要改发文字，可编辑下面的框。';
   app.ResultLabel.Text='待发送的图片（尚未发送）';app.Received.Value={entry.name;'对方先点“开始接收”，本机随后点“发送内容”。'};app.previewImage(file);
  end
  function typedText(app)
   app.FileName='';app.FileBytes=uint8([]);app.InputLabel.Text='要发送的文字 / 数字：点下面的框输入，例如 123.45';
  end
  function clearFile(app),app.typedText();app.Input.Value={''};end
  function previewImage(app,file)
   app.ImagePreview.Visible='off';[~,~,ext]=fileparts(file);
   if strcmpi(ext,'.png')&&isfile(file)
    try,app.ImagePreview.ImageSource=file;app.ImagePreview.Visible='on';catch,end
   end
  end
  function restoreLastReceive(app)
   if app.Busy||~isfolder(app.OutputRoot),return;end
   rows=dir(fullfile(app.OutputRoot,'RX_*'));[~,order]=sort([rows.datenum],'descend');
   for k=order
    folder=fullfile(rows(k).folder,rows(k).name);recordFile=fullfile(folder,'run.json');
    if ~isfile(recordFile),continue;end
    try
     r=jsondecode(fileread(recordFile));if ~isfield(r,'result')||~r.complete,continue;end
     candidates=dir(fullfile(folder,'received_payload.*'));if isempty(candidates),continue;end
     app.Serial=r.serial;app.ReceivedFile=fullfile(folder,candidates(1).name);app.showMeta(r.result.meta);
     if strcmp(r.result.meta.kind,'text'),app.Received.Value={native2unicode(uint8(r.result.bytes(:)).','UTF-8')};
     else,app.Received.Value={sprintf('%s（%d字节），文件校验通过',r.result.meta.name,r.result.meta.bytes)};end
     app.previewImage(app.ReceivedFile);app.ResultLabel.Text=['上次实际接收（非本次） · ' r.finishedUtc];
     app.Trace.reset('RX',r.mode,folder,'历史记录 / 本机USB采样');app.Trace.load(folder);
     app.Status.Text='待机 · 上方保留的是上次成功结果';app.roles();return
    catch,continue;end
   end
  end
  function openReceived(app)
   if ~app.Busy&&~isempty(app.ReceivedFile)&&isfile(app.ReceivedFile),winopen(app.ReceivedFile);end
  end
  function runAction(app,role)
   if app.Busy||app.Preview||app.Closing,return;end
   app.Role.Value=role;app.roles();
   app.Busy=true;app.Stop=false;app.Events={};app.LastResult=struct();app.ReceivedFile='';
   for k=1:8,app.Buttons(k).Enable='off';end;app.Buttons(5).Enable='on';
   app.Mode.Enable='off';app.Role.Enable='off';app.Scene.Enable='off';app.Input.Editable='off';
   app.TxGain.Enable='off';txGain=str2double(app.TxGain.Value);if strcmp(role,'RX'),txGain=NaN;end
   guard=onCleanup(@()app.finish());
   app.RunFolder=fullfile(app.OutputRoot,[role '_' char(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss')) '_' NativeUINonce()]);
   mkdir(app.RunFolder);mode=app.Mode.Value;
   app.Trace.reset(role,mode,app.RunFolder,'正在识别本机USB设备');
   record=struct('role',role,'mode',mode,'startedUtc',app.utc(),'serial',app.Serial, ...
    'centerHz',2405000000,'sampleRate',1e6,'txGainDb',txGain,'rxGainDb',30,'scene',app.Scene.Value,'networkUsedForPayload',false);
   app.ResultLabel.Text='本次操作进行中';app.ImagePreview.Visible='off';
   app.Received.Value={'本次操作处理中；上次结果已清空。'};cla(app.Ax(1));cla(app.Ax(2));app.check();
   try
    app.event('DISCOVER','识别当前插在本机USB上的Pluto');
    radios=findPlutoRadio();assert(numel(radios)==1,'DEMO:Device','本机需要恰好连接一台Pluto。');
    serial=char(radios.SerialNum);
    app.Serial=serial;record.serial=serial;app.Info.Text=['USB sn:' serial ' | RF 2.405 GHz / Fs 1 MHz'];
    app.Trace.Source=['USB …' serial(max(1,end-7):end) ' / RF 2.405GHz / Fs 1MHz'];app.Trace.refresh();
    app.event('DEVICE',['本机USB设备 sn:' serial]);
    if strcmp(role,'TX')
     if isempty(app.FileName),data=unicode2native(strjoin(string(app.Input.Value),newline),'UTF-8').';kind='text';name='message.txt';
     else,data=app.FileBytes;kind='file';name=app.FileName;end
     app.event('ENCODE','封装新无线标记、分片、编码、CRC与成形');
     [wave,meta]=demoMakeWave(data,mode,kind,name,app.Trace);record.payload=meta;app.showMeta(meta);
     app.ResultLabel.Text='本机待发送的内容';app.Received.Value=app.Input.Value;
     if strcmp(kind,'file'),previewFile=fullfile(app.RunFolder,'selected_payload.png');f=fopen(previewFile,'wb');fwrite(f,data,'uint8');fclose(f);app.previewImage(previewFile);end
     app.spectrum(wave);plot(app.Ax(2),(0:min(999,numel(wave)-1))/1e6,real(wave(1:min(1000,end))),'Color',[.2 .88 .72]);
     title(app.Ax(2),'实际发射 IQ 实部');xlabel(app.Ax(2),'时间 / s');
     save(fullfile(app.RunFolder,'tx_wave.mat'),'wave','meta','-v7.3');app.write('run.json',record);app.check();
     app.event('USB TX','连接本机Pluto，上传波形');
     app.Radio=sdrtx('Pluto','RadioID',['sn:' app.Serial],'CenterFrequency',2.405e9,'BasebandSampleRate',1e6,'Gain',txGain);
     app.check();transmitRepeat(app.Radio,wave);record.txStartedUtc=app.utc();app.write('run.json',record);clock=tic;
     app.Trace.add('07 USB上传与循环发射',{['本机Pluto sn:' app.Serial];sprintf('USB波形上传调用已返回，Pluto开始循环发射；发射增益%d dB。',txGain);['无线标记 ' meta.nonce];'下图为实际上传缓冲的样本数量和重复周期；空口结果在接收端查看。'}, ...
      {DemoTrace.plot('bar','上传样本数',1,numel(wave),'本次缓冲','复数IQ样本数'),DemoTrace.plot('bar','单次缓冲播放时长',1,numel(wave)/1e6,'本次缓冲','秒')});
     while toc(clock)<22
      app.check();app.Status.Text=sprintf('正在无线发送 · %.1f / 22 秒',toc(clock));drawnow;pause(.1);
     end
     app.release();record.txReleased=true;record.txStoppedUtc=app.utc();
     app.Trace.add('08 发射结束与记录',{'发射对象已释放，停止循环发送。';['SHA256 ' meta.sha256];'接收端独立恢复无线标记和SHA，可对照两端本次记录。'}, ...
      {DemoTrace.plot('bar','本机循环发射持续时间',1,toc(clock),'本次发射','秒'),DemoTrace.bytes(data,'本次发送的原始内容字节')});
     app.event('TX DONE','发射已停止并释放；请核对接收端标记与SHA');
     app.ResultLabel.Text='本机已发出 · 对方结果请看另一台电脑';app.Status.Text='发送结束 · 请看接收端“接收结果”';
     record.complete=true;
    else
     app.ResultLabel.Text='正在接收 · 完成后文字或图片显示在这里';
     app.event('正在接收','请让另一台电脑立即点击“发送内容”；本机采集约16秒');N=65536;count=ceil(16e6/N);
     iq=complex(zeros(N,count,'single'));valid=false(count,1);overflow=false(count,1);done=0;
     app.Radio=sdrrx('Pluto','RadioID',['sn:' app.Serial],'CenterFrequency',2.405e9,'BasebandSampleRate',1e6, ...
      'GainSource','Manual','Gain',30,'OutputDataType','single','SamplesPerFrame',N,'EnableBurstMode',true,'NumFramesInBurst',count+2);
     app.check();record.captureCallStartedUtc=app.utc();clock=tic;for k=1:2,[~,~,~]=app.Radio();app.check();end
     record.readoutStartedUtc=app.utc();last=tic;
     for k=1:count
      app.check();[iq(:,k),valid(k),overflow(k)]=app.Radio();done=k;
      assert(toc(clock)<55,'DEMO:CaptureTimeout','接收超时');
      if toc(last)>.5||k==count
       app.spectrum(iq(:,k));app.Status.Text=sprintf('正在读取接收信号 · %d / %d 块',k,count);drawnow;last=tic;
      end
     end
     app.release();record.rxReleased=true;record.samples=numel(iq);record.overflowCount=sum(overflow);record.invalidCount=sum(~valid);
     save(fullfile(app.RunFolder,'rx_iq.mat'),'iq','valid','overflow','record','-v7.3');app.check();
     [segments,~]=plutoFskContinuousSegments(valid,overflow);result=[];
     bestStages={};bestSource=app.Trace.Source;
     for j=1:size(segments,1)
      app.check();app.Trace.Stages={};app.Trace.Source=sprintf('USB …%s / 有效段%d / 原始块%d–%d / 溢出%d 无效%d',app.Serial(max(1,end-7):end),j,segments(j,1),segments(j,2),sum(overflow),sum(~valid));
      decoded=demoDecode(reshape(iq(:,segments(j,1):segments(j,2)),[],1),mode,@(stage,detail)app.event(stage,detail),app.Trace);
      if isempty(result)||(~result.complete&&decoded.complete)
       result=decoded;bestStages=app.Trace.Stages;bestSource=app.Trace.Source;
      end
      if decoded.complete,break;end
     end
     assert(~isempty(result),'DEMO:Samples','本次没有连续有效的采样片段。');
     app.Trace.Stages=bestStages;app.Trace.Source=bestSource;app.Trace.refresh();
     if ~isempty(result.symbols)
      scatter(app.Ax(2),real(result.symbols),imag(result.symbols),8,[.2 .88 .72],'.');axis(app.Ax(2),'equal');
      title(app.Ax(2),'实际同步后的接收星座');xlabel(app.Ax(2),'I');ylabel(app.Ax(2),'Q');
     elseif strcmp(mode,'2FSK'),plot(app.Ax(2),real(iq(1:1000,1)),'Color',[.2 .88 .72]);title(app.Ax(2),'FSK实际接收IQ');end
     if result.complete
      app.showMeta(result.meta);
      if strcmp(result.meta.kind,'text'),app.Received.Value={native2unicode(result.bytes.','UTF-8')};
      else,app.Received.Value={sprintf('文件已恢复：%s (%d bytes)',result.meta.name,numel(result.bytes))};end
      % Fixed destination avoids using remote filenames as filesystem paths.
      [~,~,extension]=fileparts(result.meta.name);
      if ~ismember(lower(extension),{'.png','.wav','.txt'}),extension='.bin';end
      destination=fullfile(app.RunFolder,['received_payload' lower(extension)]);
      fid=fopen(destination,'wb');assert(fid>=0,'DEMO:Write','无法保存接收载荷');fwrite(fid,result.bytes,'uint8');fclose(fid);app.ReceivedFile=destination;
      app.previewImage(destination);app.ResultLabel.Text='已收到 · 内容完整，校验通过';
     else,app.ResultLabel.Text='本次没有收到完整内容';app.Received.Value={result.reason;'请确认另一台已点“发送内容”，然后重试。'};end
     save(fullfile(app.RunFolder,'decoded.mat'),'result','-v7');
     record.complete=result.complete;record.result=rmfield(result,'symbols');
     app.event('RX DONE',sprintf('CRC有效副本 %d · CFO %.1f Hz · 完整恢复 %d',result.validFrameCopies,result.cfoHz,result.complete));
     if result.complete,app.Status.Text=sprintf('接收成功 · %d个有效帧 · 溢出%d',result.validFrameCopies,sum(overflow));
     else,app.Status.Text='接收结束 · 内容未完整恢复，请查看上方结果';end
    end
    app.Trace.save();record.processTrace='process_trace.mat';record.processStages=numel(app.Trace.Stages);
    record.finishedUtc=app.utc();app.write('run.json',record);app.LastResult=record;
   catch err
    try,app.release();catch releaseError,err=addCause(err,releaseError);end
    record.error=getReport(err,'basic','hyperlinks','off');record.complete=false;record.finishedUtc=app.utc();app.LastResult=record;
    if exist('iq','var')&&exist('done','var')&&done>0
     iq=iq(:,1:done);valid=valid(1:done);overflow=overflow(1:done);save(fullfile(app.RunFolder,'rx_partial.mat'),'iq','valid','overflow','-v7.3');
    end
    app.Trace.save();app.write('run.json',record);app.Status.Text=['已停止 / 出错 · ' err.message];app.ResultLabel.Text='本次操作未完成';
   end
  end
  function showMeta(app,m)
   app.Info.Text=sprintf('USB …%s | AIR %s | %d B | SHA256 %s',app.Serial(max(1,end-7):end),m.nonce,m.bytes,m.sha256);
  end
  function spectrum(app,wave)
   p=nativeRxPlots(wave,1e6,0);plot(app.Ax(1),p.rfFrequencyHz/1000,p.rfPowerDb,'Color',[.2 .88 .72]);
  end
  function event(app,stage,detail)
   if strcmp(stage,'频偏捕获'),stage='正在校准频率';detail='这是信号校准步骤；收到内容后才显示“接收成功”。';end
   app.check();line=[app.utc() '  ' stage '  ' detail];app.Events{end+1}=line;
   app.Events=app.Events(max(1,end-99):end);app.Log.Value=app.Events;app.Status.Text=[stage ' · ' detail];drawnow;
   if ~isempty(app.RunFolder),app.write('events.json',app.Events);end
  end
  function check(app),if app.Stop||app.Closing,error('DEMO:Stopped','操作已停止');end,end
  function stop(app),app.Stop=true;end
  function close(app)
   app.Closing=true;app.Stop=true;if ~app.Busy,app.release();app.Trace.close();delete(app.Figure);end
  end
  function release(app)
   if ~isempty(app.Radio),release(app.Radio);app.Radio=[];end
  end
  function finish(app)
   try,app.release();catch
    app.Status.Text='设备释放失败，请断开本机Pluto USB；本窗口已禁止再次操作。';
    for k=1:8,app.Buttons(k).Enable='off';end
    return
   end
   app.Busy=false;if app.Closing,app.Trace.close();delete(app.Figure);else,app.roles();end
  end
  function write(app,name,value)
   file=fullfile(app.RunFolder,name);fid=fopen([file '.tmp'],'w','n','UTF-8');assert(fid>=0,'DEMO:Write','记录无法保存');
   cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value));clear cleanup;movefile([file '.tmp'],file,'f');
  end
 end
 methods(Static)
  function s=utc(),s=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));end
  function s=onoff(v),if v,s='on';else,s='off';end,end
 end
end

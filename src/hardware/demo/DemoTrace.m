classdef DemoTrace < handle
 % Bounded views of actual intermediate arrays. Never supplies data to RX.
 properties
  Stages={}; Role=''; Mode=''; Folder=''; Identity='尚未开始'; Source=''; Progress=[];
  Figure=[]; List; Ax; Notes; Banner; Follow; Overview; Tabs; DetailTab; SummaryTab; RenderingOverview=false;
 end
 methods
  function reset(t,role,mode,folder,source)
   t.Stages={};t.Role=role;t.Mode=mode;t.Folder=folder;t.Source=source;
   [~,run]=fileparts(folder);t.Identity=[role ' / ' mode ' / ' run];t.refresh();
  end
  function add(t,name,description,plots)
   if nargin<4,plots={};end
   s=struct('name',name,'description',{description},'plots',{plots},'utc',PlutoTerminal.utc());
   t.Stages{end+1}=s;t.refresh();
   if ~isempty(t.Progress),d=cellstr(string(description));t.Progress(name,d{1});end
  end
  function save(t)
   if isempty(t.Folder)||isempty(t.Stages),return;end
   trace=struct('version',1,'role',t.Role,'mode',t.Mode,'identity',t.Identity,'source',t.Source,'stages',{t.Stages});
   save(fullfile(t.Folder,'process_trace.mat'),'trace','-v7');
  end
  function load(t,folder)
   p=fullfile(folder,'process_trace.mat');if ~isfile(p),return;end
   a=load(p,'trace');r=a.trace;t.Role=r.role;t.Mode=r.mode;t.Folder=folder;
   t.Identity=['历史记录 / ' r.identity];t.Source=r.source;t.Stages=r.stages;t.refresh();
  end
  function show(t,visible)
   if nargin<2,visible='on';end
   if ~isempty(t.Figure)&&isgraphics(t.Figure),t.Figure.Visible=visible;return;end
   bg=[.035 .055 .075];fg=[.82 .89 .90];accent=[.2 .88 .72];
   t.Figure=uifigure('Name','PLUTO // 逐步过程与实测证据','Position',[70 45 1240 850],'Color',bg,'Visible',visible);
   g=uigridlayout(t.Figure,[4 1],'RowHeight',{42,34,'1x',54},'BackgroundColor',bg);
   t.Banner=uilabel(g,'Text',t.Identity,'FontColor',accent,'FontWeight','bold','FontSize',15,'Interpreter','none');
   buttons=uigridlayout(g,[1 4],'ColumnWidth',{180,180,150,'1x'},'Padding',0,'BackgroundColor',bg);
   t.Follow=uicheckbox(buttons,'Text','跟随实际处理阶段','Value',true,'FontColor',fg);
   uibutton(buttons,'Text','保存全部步骤图片','ButtonPushedFcn',@(~,~)t.export());
   uibutton(buttons,'Text','打开本次记录','ButtonPushedFcn',@(~,~)t.openFolder());
   uilabel(buttons,'Text','左侧选步骤放大；“全部小图”可一次看完整条链路','FontColor',fg);
   t.Tabs=uitabgroup(g);t.DetailTab=uitab(t.Tabs,'Title','逐步放大');t.SummaryTab=uitab(t.Tabs,'Title','全部小图');
   t.Tabs.SelectionChangedFcn=@(~,~)t.overview();
   a=uigridlayout(t.DetailTab,[2 2],'ColumnWidth',{210,'1x'},'RowHeight',{'1x',155},'BackgroundColor',bg);
   t.List=uilistbox(a,'Items',{'等待本次数据'},'ValueChangedFcn',@(~,~)t.select(),'BackgroundColor',[.065 .09 .115],'FontColor',fg,'FontSize',14);t.List.Layout.Row=[1 2];
   charts=uigridlayout(a,[2 1],'RowHeight',{'1x','1x'},'BackgroundColor',bg);charts.Layout.Row=1;charts.Layout.Column=2;
   t.Ax=gobjects(1,2);for k=1:2,t.Ax(k)=uiaxes(charts);end
   t.Notes=uitextarea(a,'Editable','off','FontSize',14,'BackgroundColor',[.065 .09 .115],'FontColor',fg);t.Notes.Layout.Row=2;t.Notes.Layout.Column=2;
   t.Overview=uigridlayout(t.SummaryTab,[1 2],'BackgroundColor',bg,'Scrollable','on');
   foot=uitextarea(g,'Editable','off','Value',{'图像来自本机这一轮实际数组；步骤时间是本机处理时间。发送图显示交给Pluto的数字波形。';'接收证据：本机USB原始IQ → 独立解调 → CRC有效分片 → 文件SHA。完整IQ和过程图保存在本次记录中。'},'FontSize',12,'BackgroundColor',bg,'FontColor',fg);
   t.refresh();
  end
  function select(t)
   t.Follow.Value=false;t.render();
  end
  function refresh(t)
   if isempty(t.Figure)||~isgraphics(t.Figure),return;end
   t.Banner.Text=[t.Identity ' | ' t.Source];
   if isempty(t.Stages)
    t.List.Items={'等待本次数据'};t.List.ItemsData=0;t.List.Value=0;
    for ax=t.Ax,cla(ax);title(ax,'等待本次数据');end
    t.Notes.Value={'实际处理到某一步后，对应图像才会出现。'};
    delete(t.Overview.Children);return
   end
   old=t.List.Value;if ~isnumeric(old),old=1;end
   labels=cellfun(@(s)s.name,t.Stages,'UniformOutput',false);
   t.List.ItemsData=[];t.List.Items=labels;t.List.ItemsData=1:numel(labels);
   if t.Follow.Value,t.List.Value=numel(labels);else,t.List.Value=max(1,min(old,numel(labels)));end
   t.render();if t.Tabs.SelectedTab==t.SummaryTab,t.overview();end
   drawnow limitrate;
  end
  function render(t)
   k=t.List.Value;if ~isnumeric(k)||k<1||k>numel(t.Stages),return;end
   s=t.Stages{k};t.Notes.Value=[{[s.name '  |  UTC ' s.utc]};cellstr(string(s.description(:)))];
   for j=1:2
    if j<=numel(s.plots),DemoTrace.draw(t.Ax(j),s.plots{j});else,cla(t.Ax(j));title(t.Ax(j),'本步骤无附加图');end
   end
  end
  function overview(t)
   if isempty(t.Figure)||~isgraphics(t.Figure)||t.Tabs.SelectedTab~=t.SummaryTab,return;end
   if t.RenderingOverview,return;end
   t.RenderingOverview=true;guard=onCleanup(@()t.endOverview());
   delete(t.Overview.Children);n=numel(t.Stages);t.Overview.RowHeight=repmat({220},1,n);
   for k=1:n
    s=t.Stages{k};for j=1:min(2,numel(s.plots))
     ax=uiaxes(t.Overview);ax.Layout.Row=k;ax.Layout.Column=j;DemoTrace.draw(ax,s.plots{j});title(ax,[s.name ' / ' s.plots{j}.title],'Interpreter','none');
    end
   end
   drawnow;
  end
  function endOverview(t),t.RenderingOverview=false;end
  function openFolder(t)
   if ~isempty(t.Folder)&&isfolder(t.Folder),winopen(t.Folder);end
  end
  function export(t)
   if isempty(t.Folder)||isempty(t.Stages),return;end
   t.save();folder=fullfile(t.Folder,'过程图片');if ~isfolder(folder),mkdir(folder);end
   f=figure('Visible','off','Color','w','Position',[0 0 1400 850]);guard=onCleanup(@()close(f));
   for k=1:numel(t.Stages)
    clf(f);s=t.Stages{k};layout=tiledlayout(f,2,1,'Padding','compact');
    for j=1:min(2,numel(s.plots)),ax=nexttile(layout);DemoTrace.draw(ax,s.plots{j});end
    title(layout,{[t.Identity ' / ' s.name],t.Source},'Interpreter','none','FontSize',12);
    exportgraphics(f,fullfile(folder,sprintf('%02d.png',k)),'Resolution',120);
   end
   if ~isempty(t.Figure)&&isgraphics(t.Figure),t.Banner.Text=['已保存 ' num2str(numel(t.Stages)) ' 张步骤图到本次记录 / 过程图片'];end
  end
  function close(t)
   if ~isempty(t.Figure)&&isgraphics(t.Figure),delete(t.Figure);end
  end
 end
 methods(Static)
  function p=plot(kind,titleText,x,y,xlabelText,ylabelText)
   p=struct('kind',kind,'title',titleText,'x',double(x),'y',double(y),'xlabel',xlabelText,'ylabel',ylabelText);
  end
  function p=bits(bits,label)
   v=double(bits(1:min(256,end)));p=DemoTrace.plot('stairs',label,1:numel(v),v,'前256位中的位序号','比特 0 / 1');
  end
  function p=bytes(bytes,label)
   v=double(bytes(1:min(96,end)));p=DemoTrace.plot('bar',label,1:numel(v),v,'前96字节中的字节序号','字节值 0–255');
  end
  function plots=signal(x,fs,label)
   n=min(2048,numel(x));v=x(1:n);p=DemoTrace.plot('line',[label ' / I与Q'],(0:n-1)'/fs*1e3,[real(v(:)) imag(v(:))],'时间 / ms','数字幅度');
   p.legend={'I 实部','Q 虚部'};plots={p,DemoTrace.spectrum(x,fs,[label ' / 频谱'])};
  end
  function p=spectrum(x,fs,label)
   n=min(32768,numel(x));if n<2,p=DemoTrace.plot('line',label,[],[],'频率 / kHz','相对谱功率 / dB');return;end
   v=double(x(1:n));v=v(:);w=.5-.5*cos(2*pi*(0:n-1)'/(n-1));N=2^nextpow2(n);
   power=abs(fftshift(fft(v.*w,N))).^2;power=10*log10(max(power,realmin)/max(max(power),realmin));
   % Peak-preserving bins keep narrow calibration tones visible.
   edges=round(linspace(1,N+1,min(2048,N)+1));idx=zeros(numel(edges)-1,1);
   for k=1:numel(idx),r=edges(k):edges(k+1)-1;[~,at]=max(power(r));idx(k)=r(at);end
   p=DemoTrace.plot('line',label,(idx-1-N/2)*fs/N/1000,power(idx),'基带频率 / kHz','相对峰值 / dB');
  end
  function p=eye(x,sps,label)
   n=min(64,floor(numel(x)/(2*sps)));v=reshape(real(x(1:n*2*sps)),2*sps,n);
   p=DemoTrace.plot('eye',label,(0:2*sps-1)'/sps,v,'相对码元时间（2个码元）','I幅度');
  end
  function p=constellation(x,label)
   v=x(1:min(2048,end));p=DemoTrace.plot('scatter',label,real(v),imag(v),'I 实部','Q 虚部');
  end
  function draw(ax,p)
   cla(ax,'reset');ax.Color=[.065 .09 .115];ax.XColor=[.82 .89 .9];ax.YColor=ax.XColor;ax.GridColor=[.3 .4 .45];
   c=[.2 .88 .72];
   if isempty(p.y),text(ax,.5,.5,'本次没有该阶段的有效数据','Units','normalized','HorizontalAlignment','center','Color',c);
   else
    switch p.kind
     case 'scatter',scatter(ax,p.x,p.y,7,c,'.');axis(ax,'equal');
     case 'stairs',stairs(ax,p.x,p.y,'Color',c);ylim(ax,[-.2 1.2]);
     case 'bar',bar(ax,p.x,p.y,'FaceColor',c);
     case 'eye',plot(ax,p.x,p.y,'Color',[.18 .6 .53]);
     otherwise,plot(ax,p.x,p.y,'LineWidth',1);
    end
   end
   ax.Color=[.065 .09 .115];ax.XColor=[.82 .89 .9];ax.YColor=ax.XColor;ax.GridColor=[.3 .4 .45];ax.FontSize=11;
   if strcmp(p.kind,'scatter')&&~isempty(p.y),lim=max(.2,max(abs([p.x(:);p.y(:)]))*1.25);xlim(ax,[-lim lim]);ylim(ax,[-lim lim]);end
   grid(ax,'on');title(ax,p.title,'Interpreter','none','Color',[.82 .89 .9]);xlabel(ax,p.xlabel,'Color',ax.XColor);ylabel(ax,p.ylabel,'Color',ax.YColor);
   if isfield(p,'legend')&&~isempty(p.y),lg=legend(ax,p.legend,'Location','best');lg.TextColor=[.82 .89 .9];lg.Color=ax.Color;end
  end
 end
end

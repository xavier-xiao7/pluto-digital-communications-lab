function app = commLabLauncher(options)
% Desktop entry point. All experiment computations use the existing sources.
arguments
    options.Visible (1,1) logical = true
    options.AutoRun (1,1) logical = true
    options.OpenModels (1,1) logical = true
    options.Destination char = ''
end
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
advanced = fullfile(root,'src','psk');
fsk = fullfile(root,'src','fsk');
addpath(here);
% This dedicated desktop is launched in this neutral directory, not an MLX directory.
cd(here);
busy = false; lastResult = struct(); destination = ''; gallery = struct('name',{},'path',{});
controls = gobjects(0);
requestPath=getenv('COMM_LAB_REQUEST_FILE'); reopenTimer=[];
screen = get(groot,'ScreenSize');
windowSize = min([1240 830],screen(3:4)-[50 100]);
win = uifigure('Name','通信系统综合实验 · 一键仿真','Position',[25 50 windowSize], ...
    'Visible','off','Color',[.96 .97 .98],'Tag','CommLabLauncher');
win.CloseRequestFcn = @closeWindow;
win.DeleteFcn = @deleteWindow;
layout = uigridlayout(win,[7 1]);
layout.RowHeight = {42,25,40,34,'1x',25,22}; layout.Padding = [22 16 22 14];
titleText = uilabel(layout,'Text','通信系统综合实验','FontSize',25,'FontWeight','bold');
titleText.FontColor = [.08 .15 .23];
uilabel(layout,'Text','Digital Communications Lab  |  FSK / BPSK / QPSK 与扩展实验', ...
    'FontSize',13,'FontColor',[.28 .35 .42]);
bar = uigridlayout(layout,[1 5]); bar.Padding = [0 0 0 0];
bar.ColumnWidth = {158,104,130,130,'1x'};
startButton = uibutton(bar,'Text','重新运行全部演示','ButtonPushedFcn',@(~,~)runDemos, ...
    'BackgroundColor',[.10 .36 .63],'FontColor',[1 1 1],'FontWeight','bold');
mode = uidropdown(bar,'Items',{'2FSK','BPSK','QPSK'},'Value','QPSK');
modelButton = uibutton(bar,'Text','打开所选模型','ButtonPushedFcn',@(~,~)openSelected);
uibutton(bar,'Text','本次结果文件','ButtonPushedFcn',@(~,~)openResults);
controls = [startButton;mode;modelButton];
status = uilabel(layout,'Text','正在准备演示…','FontSize',15,'FontWeight','bold');
tabs = uitabgroup(layout);
overview = uitab(tabs,'Title','运行进度与结果');
overviewGrid = uigridlayout(overview,[2 1]); overviewGrid.RowHeight = {'1x',125};
resultsTable = uitable(overviewGrid,'ColumnName',{'实验','状态','本次结果'}, ...
    'ColumnWidth',{220,90,'auto'},'RowName',{},'Data',cell(0,3),'FontSize',13);
logBox = uitextarea(overviewGrid,'Editable','off','Value',{'启动后自动运行功能演示，每项结果会显示在上方。'});
plotsTab = uitab(tabs,'Title','波形、眼图、星座与扩展图');
plotGrid = uigridlayout(plotsTab,[2 2]); plotGrid.ColumnWidth = {230,'1x'};
plotGrid.RowHeight = {'1x',42};
plotList = uilistbox(plotGrid,'Items',{'本次图表生成后在此选择'},'FontSize',13, ...
    'ValueChangedFcn',@(~,~)showImage);
picture = uiimage(plotGrid,'ScaleMethod','fit');
plotNote = uilabel(plotGrid,'Text','图表来自本次运行。','WordWrap','on','FontColor',[.28 .35 .42]);
plotNote.Layout.Row = 2; plotNote.Layout.Column = [1 2];
historyButton = uibutton(layout,'Text','实验说明 / Documentation', ...
    'ButtonPushedFcn',@(~,~)openFile(fullfile(root,'README.zh-CN.md')));
historyButton.BackgroundColor = [.91 .94 .97];
uilabel(layout,'Text','本窗口运行软件仿真；声卡部分使用离线 WAV。每次结果单独保存。', ...
    'FontSize',11,'FontColor',[.35 .40 .45]);
app = struct('Window',win,'RunAll',@runDemos,'OpenModel',@prepareModel, ...
    'Result',@getResult,'Gallery',@getGallery,'ShowImage',@showImage);
setappdata(win,'CommLabApp',app);
if options.Visible, win.Visible = 'on'; end
if ~isempty(requestPath)
    reopenTimer=timer('Name','CommLabReopen','ExecutionMode','fixedSpacing','Period',1, ...
        'BusyMode','drop','TimerFcn',@pollReopen);
    start(reopenTimer);
end
writeReady;
if options.AutoRun, runDemos; else, status.Text = '准备就绪，点击“重新运行全部演示”。'; end

    function runDemos
        if busy, return; end
        if ~modelsIdle, addLog('请等待当前模型运行结束，再启动全部演示。'); return; end
        busy = true; enableControls(false);
        resultsTable.Data = cell(0,3); logBox.Value = {'正在启动仿真，首次加载 MATLAB / Simulink 需要稍等。'};
        tabs.SelectedTab = overview;
        if isempty(options.Destination)
            destination = fullfile(root,'results','simulation',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
        else
            destination = options.Destination;
        end
        try
            lastResult = runCommLabDemos(root,destination,@progress);
            gallery = lastResult.gallery;
            if ~isempty(gallery)
                plotList.Items = {gallery.name}; plotList.Value = gallery(1).name; showImage;
            end
            if lastResult.allPassed
                status.Text = sprintf('全部演示完成 · %d/%d 项通过',sum([lastResult.cases.passed]),numel(lastResult.cases));
                status.FontColor = [.08 .40 .22];
            else
                status.Text = sprintf('演示结束 · %d 项需查看结果说明',sum(~[lastResult.cases.passed]));
                status.FontColor = [.65 .24 .08];
            end
            addLog(['结果目录：' destination]);
            if options.OpenModels
                prepareModel('2FSK',true); prepareModel('QPSK',true);
                addLog('FSK 和 QPSK 模型已打开；在上方选择 BPSK 可切换高级模型。');
            end
        catch exception
            status.Text = '启动遇到问题，详细原因见下方记录。'; status.FontColor = [.70 .17 .12];
            addLog(getReport(exception,'extended','hyperlinks','off'));
            if ~isfolder(destination), mkdir(destination); end
            fid = fopen(fullfile(destination,'启动错误.txt'),'w','n','UTF-8');
            if fid>=0, fprintf(fid,'%s',getReport(exception,'extended','hyperlinks','off')); fclose(fid); end
        end
        finishBusy; drawnow;
    end

    function progress(index,total,name,state,detail)
        data = resultsTable.Data;
        if size(data,1)<total, data(end+1:total,1:3) = {''}; end
        data(index,:) = {name,state,detail}; resultsTable.Data = data;
        status.Text = sprintf('%d/%d  %s · %s',index,total,name,state);
        status.FontColor = [.08 .24 .40];
        if ~strcmp(state,'正在运行'), addLog([name '：' detail]); end
        drawnow limitrate;
    end

    function openSelected
        try, prepareModel(mode.Value,true);
        catch exception, uialert(win,exception.message,'模型打开失败'); end
    end

    function mdl = prepareModel(selected,showWindow)
        % Each model's InitFcn reconstructs its own base variables on every Run.
        % FSK and advanced models can therefore be kept open in one MATLAB desktop.
        assert(modelsIdle,'当前模型仍在运行，请在运行结束后切换。');
        addpath(advanced,fsk,here);
        if strcmp(selected,'2FSK')
            mdl = 'stuFskSimulation'; modelPath = fullfile(fsk,[mdl '.slx']);
        else
            mdl = 'stuAdvancedSimulation'; modelPath = fullfile(advanced,[mdl '.slx']);
        end
        if bdIsLoaded(mdl)
            assert(strcmpi(get_param(mdl,'FileName'),modelPath),'已加载另一目录的同名模型，请在本启动窗口使用配套工程。');
        end
        load_system(modelPath);
        if strcmp(selected,'2FSK')
            set_param(mdl,'InitFcn','commLabModelCallbacks(''init'',''2FSK'');', ...
                'StopFcn','commLabModelCallbacks(''stop'',''2FSK'');','ReturnWorkspaceOutputs','off');
            commLabModelCallbacks('init','2FSK');
        else
            assignin('base','msg','BPSK and QPSK digital communications test.');
            assignin('base','advOptions',struct('modulation',selected,'channelMode','combined'));
            set_param(mdl,'InitFcn','commLabModelCallbacks(''init'',''PSK'');','StopFcn','advStopModel;','ReturnWorkspaceOutputs','off');
            advInitModel;
        end
        set_param(mdl,'EnablePacing','off');
        if showWindow, open_system(mdl); end
    end

    function showImage
        if isempty(gallery), return; end
        index = find(strcmp({gallery.name},plotList.Value),1);
        if isempty(index), index=1; end
        picture.ImageSource = gallery(index).path;
        plotNote.Text = [gallery(index).name '  |  本次实际运行生成；可在“本次结果文件”中查看原图。'];
    end
    function openResults
        if isempty(destination), openFile(here); else, openFile(destination); end
    end
    function openFile(file)
        if isfile(file)||isfolder(file), winopen(file);
        else, uialert(win,['未找到文件：' file],'文件位置'); end
    end
    function addLog(message)
        lines = [string(logBox.Value(:));splitlines(string(message))];
        logBox.Value = cellstr(lines(max(1,numel(lines)-60):end));
    end
    function enableControls(value)
        setting='off'; if value,setting='on';end
        for k=1:numel(controls), if isvalid(controls(k)),controls(k).Enable=setting;end,end
    end
    function finishBusy
        busy=false; enableControls(true);
    end
    function result=getResult
        result=lastResult;
    end
    function value=getGallery
        value=gallery;
    end
    function idle=modelsIdle
        idle=true;
        for name={'stuFskSimulation','stuAdvancedSimulation'}
            if bdIsLoaded(name{1}) && ~strcmp(get_param(name{1},'SimulationStatus'),'stopped')
                idle=false; return;
            end
        end
    end
    function closeWindow(~,~)
        if busy
            status.Text='当前实验正在计算，完成后可关闭窗口。'; return;
        end
        if isempty(requestPath),delete(win);else,win.Visible='off';end
    end
    function pollReopen(~,~)
        if isfile(requestPath)
            delete(requestPath);
            if options.Visible,win.Visible='on';figure(win);end
        end
    end
    function deleteWindow(~,~)
        if ~isempty(reopenTimer)&&isvalid(reopenTimer)
            stop(reopenTimer);delete(reopenTimer);
        end
    end
    function writeReady
        statePath = getenv('COMM_LAB_READY_FILE');
        if isempty(statePath), return; end
        fid = fopen(statePath,'w','n','UTF-8');
        if fid>=0, fprintf(fid,'{"ready":true}'); fclose(fid); end
    end
end

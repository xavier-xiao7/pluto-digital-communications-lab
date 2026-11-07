function result = runCommLabDemos(projectRoot,destination,onProgress)
% Run the acceptance demonstrations into a fresh, separate result directory.
% This function performs software simulation only and never opens hardware.
if nargin<3 || isempty(onProgress),onProgress=@(~,~,~,~,~)[];end
projectRoot=char(projectRoot);destination=char(destination);
advanced=fullfile(projectRoot,'src','psk');
fsk=fullfile(projectRoot,'src','fsk');
assert(isfolder(advanced)&&isfolder(fsk),'COMM:MissingProject','找不到两套仿真工程。');
if ~isfolder(destination),mkdir(destination);end
assert(~isfile(fullfile(destination,'demo_summary.json')),'COMM:ExistingRun', ...
    '本次输出目录已有演示记录，请使用新的运行目录。');
oldPath=path;oldFolder=pwd;
pathGuard=onCleanup(@()restoreLocation(oldPath,oldFolder)); %#ok<NASGU>
cd(destination);addpath(advanced,fsk,'-begin');
oldGeneration=Simulink.fileGenControl('getConfig');
generationGuard=onCleanup(@()restoreGeneration(oldGeneration)); %#ok<NASGU>
Simulink.fileGenControl('set','CacheFolder',fullfile(destination,'cache'), ...
    'CodeGenFolder',fullfile(destination,'code_cache'),'createDir',true);
loadExpectedModel('stuFskSimulation',fullfile(fsk,'stuFskSimulation.slx'));
loadExpectedModel('stuAdvancedSimulation',fullfile(advanced,'stuAdvancedSimulation.slx'));
fskCallbacks=struct('InitFcn',get_param('stuFskSimulation','InitFcn'), ...
    'StopFcn',get_param('stuFskSimulation','StopFcn'), ...
    'ReturnWorkspaceOutputs',get_param('stuFskSimulation','ReturnWorkspaceOutputs'));
callbackGuard=onCleanup(@()restoreFskCallbacks(fskCallbacks)); %#ok<NASGU>
set_param('stuFskSimulation','InitFcn','','StopFcn','','ReturnWorkspaceOutputs','on','EnablePacing','off');
set_param('stuAdvancedSimulation','EnablePacing','off');

names={'2FSK 文本与码元同步','BPSK 组合信道','QPSK 组合信道', ...
    'QPSK 矩形成型对照','Manchester + SECDED + 交织', ...
    'UTF-8 文本文件传输','PNG 图片文件传输','WAV 音频文件传输', ...
    '5330 字节长文传输','码型、纠错与交织对照','声卡 2FSK 离线仿真','同步、眼图、星座与频谱图'};
emptyCase=struct('name','','passed',false,'detail','','seconds',0,'error','');
result=struct('destination',destination,'matlab',version, ...
    'startedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'finishedAt','','allPassed',false,'physicalRadioTested',false, ...
    'physicalAudioTested',false,'cases',repmat(emptyCase,1,numel(names)), ...
    'gallery',struct('name',{},'path',{}));
snapshots=struct();media=[];
message=uint8('BPSK and QPSK digital communications test.').';
for index=1:numel(names)
    result.cases(index).name=names{index};
    notify(index,'正在运行','正在计算本次结果');
    started=tic;
    try
        detail='';
        switch index
            case 1
                msg='Hello, world! Lab 2FSK communication experiment 2026.';
                [out,rx,cfg,truth]=runFskExperiment(msg);
                assert(rx.complete&&strcmp(rx.message,msg),'COMM:FskMismatch','FSK 接收文本未完整一致。');
                detail=sprintf('%d 字节全文一致；%d/%d 合格帧副本；PLL 码元同步。', ...
                    numel(msg),rx.validFrameCount,truth.frameCount*cfg.repetitions);
                save(fullfile(destination,'fsk_result.mat'),'out','rx','cfg','truth','msg','-v7');
                imagePath=fullfile(destination,'FSK_本次同步波形.png');
                drawFsk(rx,cfg,imagePath);
                addGallery('2FSK · 同步采样与时钟',imagePath);
            case {2,3,4}
                if index==2
                    options=struct('modulation','BPSK');key='BPSK_combined';
                elseif index==3
                    options=struct('modulation','QPSK');key='QPSK_combined';
                else
                    options=struct('modulation','QPSK','pulseShape','rectangular');key='QPSK_rectangular';
                end
                [out,rx,cfg,truth]=runAdvancedExperiment(message,options);
                detail=verifyBytes(rx,truth,message);
                snapshots.(key)=struct('out',out,'rx',rx,'cfg',cfg,'truth',truth);
            case 5
                bytes=uint8((0:255).');
                options=struct('modulation','QPSK','protocol', ...
                    struct('lineCode','Manchester','fec',true,'interleave',true));
                [~,rx,~,truth]=runAdvancedExperiment(bytes,options);
                detail=verifyBytes(rx,truth,bytes);
            case {6,7,8}
                if isempty(media),media=createExtensionPayloads(fullfile(destination,'发送素材'));end
                item=media(index-5);
                options=struct('modulation','QPSK','protocol',struct('payloadType',item.payloadType));
                [~,rx,~,truth]=runAdvancedExperiment(item.bytes,options);
                detail=verifyBytes(rx,truth,item.bytes);
                [~,stem,extension]=fileparts(item.path);
                writeAndVerify(fullfile(destination,'恢复文件','QPSK',[stem extension]),rx.bytes,item.bytes);
            case 9
                bytes=uint8(repmat('Long message segment 0123456789 ABC xyz. ',1,130)).';
                assert(numel(bytes)==5330,'COMM:LongTextSize','长文大小发生变化。');
                [~,rx,~,truth]=runAdvancedExperiment(bytes,struct('modulation','QPSK'));
                detail=verifyBytes(rx,truth,bytes);
                writeAndVerify(fullfile(destination,'恢复文件','QPSK','long_text.txt'),rx.bytes,bytes);
            case 10
                coding=validateCodingExtensions(fullfile(destination,'coding'));
                assert(coding.burst.interleavedDecodedErrors==0,'COMM:Interleaver','交织突发纠错未完整恢复。');
                detail=sprintf('5 个公平能量 BER 点；16 bit 突发经交织后剩余 %d 错；NRZ / Manchester 波形和频谱。', ...
                    coding.burst.interleavedDecodedErrors);
                addGallery('码型 · NRZ 与 Manchester',coding.artifacts.lineCodePng);
                addGallery('纠错 · 公平能量 BER',coding.artifacts.berPng);
                addGallery('交织 · 16 bit 突发错误',coding.artifacts.burstPng);
            case 11
                soundcard=validateSoundcardOffline(fullfile(destination,'soundcard'));
                assert(soundcard.allPassed,'COMM:Audio','声卡离线检查未全部达到预期。');
                detail=sprintf('%d/%d 条件符合预期，WAV 写入读回一致；软件内离线计算。', ...
                    sum([soundcard.cases.passed]),numel(soundcard.cases));
                addGallery('声卡离线 · 同步与钟偏',fullfile(destination,'soundcard','声卡同步与钟偏.png'));
            case 12
                assert(all(isfield(snapshots,{'BPSK_combined','QPSK_combined','QPSK_rectangular'})), ...
                    'COMM:MissingSnapshots','需要本次 BPSK、QPSK 和矩形成型结果才能绘图。');
                snapshotPath=fullfile(destination,'advanced_snapshots.mat');
                save(snapshotPath,'snapshots','-v7');
                createAdvancedFigures(fullfile(destination,'figures'),snapshotPath);
                stems={'BPSK_同步眼图星座','QPSK_同步眼图星座','成型频谱与码间干扰', ...
                    '图片与音频恢复','Simulink总模型','Simulink调制与成型','Simulink解调与匹配滤波'};
                labels={'BPSK · 同步、眼图与星座','QPSK · 同步、眼图与星座','RRC / 矩形 · 频谱与码间干扰', ...
                    'PNG / WAV · 收发恢复对照','模型 · 总链路','模型 · 调制与成型','模型 · 解调与匹配滤波'};
                for j=1:numel(stems)
                    imagePath=fullfile(destination,'figures',[stems{j} '.png']);
                    if isfile(imagePath),addGallery(labels{j},imagePath);end
                end
                detail='从本次 Simulink 波形、接收估计和恢复文件生成图表。';
        end
        result.cases(index).passed=true;
        result.cases(index).detail=detail;
        result.cases(index).seconds=toc(started);
        notify(index,'通过',detail);
    catch problem
        result.cases(index).seconds=toc(started);
        result.cases(index).detail=problem.message;
        result.cases(index).error=getReport(problem,'extended','hyperlinks','off');
        notify(index,'失败',problem.message);
        fprintf(2,'%s\n',result.cases(index).error);
    end
    result.allPassed=all([result.cases.passed]);
    writeJson(fullfile(destination,'demo_summary.json'),result);
end
result.finishedAt=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
result.allPassed=all([result.cases.passed]);
writeJson(fullfile(destination,'demo_summary.json'),result);
fprintf('COMM_LAB_DEMOS: %d/%d demonstrations passed.\n',sum([result.cases.passed]),numel(names));

    function notify(number,status,detail)
        fprintf('[%d/%d] %s: %s — %s\n',number,numel(names),names{number},status,detail);
        try,onProgress(number,numel(names),names{number},status,detail);
        catch progressError
            warning('COMM:ProgressDisplay','进度显示未更新：%s',progressError.message);
        end
    end
    function addGallery(name,imagePath)
        assert(isfile(imagePath),'COMM:MissingFigure','图表不存在：%s',imagePath);
        result.gallery(end+1)=struct('name',name,'path',imagePath);
    end
end

function detail=verifyBytes(rx,truth,expected)
assert(rx.complete&&isequal(rx.bytes(:),expected(:)),'COMM:PayloadMismatch','接收字节未完整一致。');
[~,hash]=advSha256(rx.bytes);
assert(strcmp(hash,truth.sha256Hex),'COMM:HashMismatch','整消息 SHA-256 不一致。');
detail=sprintf('%d 字节内容一致；%d/%d 合格帧副本。', ...
    numel(expected),rx.validFrameCount,truth.expectedCopies);
end

function writeAndVerify(file,bytes,expected)
folder=fileparts(file);if ~isfolder(folder),mkdir(folder);end
fid=fopen(file,'wb');assert(fid>=0,'COMM:FileWrite','无法写入恢复文件。');
closer=onCleanup(@()fclose(fid));fwrite(fid,bytes,'uint8');clear closer
fid=fopen(file,'rb');assert(fid>=0,'COMM:FileRead','无法读取恢复文件。');
closer=onCleanup(@()fclose(fid));actual=fread(fid,Inf,'*uint8');clear closer
assert(isequal(actual(:),expected(:)),'COMM:FileMismatch','写回磁盘后字节不同。');
end

function drawFsk(rx,cfg,file)
fig=figure('Visible','off','Color','w','Position',[50 50 1100 740]);
closer=onCleanup(@()close(fig));layout=tiledlayout(fig,2,1,'TileSpacing','compact');
time=(0:numel(rx.normalizedWave)-1).'/cfg.fs;
ax=nexttile(layout);plot(ax,time,rx.normalizedWave);hold(ax,'on');
samples=rx.sampleIndices;scatter(ax,time(samples),rx.normalizedWave(samples),12,'r','filled');
xlim(ax,[0.12 min(0.16,time(end))]);ylim(ax,[-1.2 1.2]);grid(ax,'on');
xlabel(ax,'Time / s');ylabel(ax,'Normalized energy difference');
title(ax,'2FSK: actual received energy metric and recovered sample instants');
legend(ax,{'Energy metric','RX-estimated samples'},'Location','best');
ax=nexttile(layout);plot(ax,time(samples),(rx.timingPeriodSamples/cfg.sps-1)*1e6);
grid(ax,'on');xlabel(ax,'Time / s');ylabel(ax,'Estimated clock offset / ppm');
title(ax,'Transition-driven timing PLL');
exportgraphics(fig,file,'Resolution',140);clear closer
end

function loadExpectedModel(name,file)
if bdIsLoaded(name)
    assert(strcmpi(get_param(name,'FileName'),file),'COMM:ModelConflict', ...
        '已打开另一路径的 %s，请先关闭该同名模型。',name);
else
    load_system(file);
end
end

function restoreFskCallbacks(previous)
if bdIsLoaded('stuFskSimulation')
    set_param('stuFskSimulation','InitFcn',previous.InitFcn,'StopFcn',previous.StopFcn, ...
        'ReturnWorkspaceOutputs',previous.ReturnWorkspaceOutputs);
end
end

function restoreGeneration(previous)
Simulink.fileGenControl('set','CacheFolder',previous.CacheFolder, ...
    'CodeGenFolder',previous.CodeGenFolder,'createDir',true);
end

function restoreLocation(previousPath,previousFolder)
path(previousPath);if isfolder(previousFolder),cd(previousFolder);end
end

function writeJson(file,data)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'COMM:SummaryWrite','无法保存本次演示记录。');
closer=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(data,PrettyPrint=true));
end

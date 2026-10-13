function results = Choice_side_plot_Subject3to5_ChoiceAnalysis(dataDir, outputDir)
% 按实际响应手分组的同侧选择比例：原Choice_side_plot的Subject3-5组版本。
% 左手：P(Left Target | Left Hand)；右手：P(Right Target | Right Hand)。
% 注意：这是按手条件化的概率，不是所有试次的总体同侧比例。
% 用法：results = Choice_side_plot_Subject3to5_ChoiceAnalysis;
% 或 results = Choice_side_plot_Subject3to5_ChoiceAnalysis('数据目录','输出目录');
% 默认读脚本所在目录/data；若不存在，使用用户提供的Windows数据目录。
% 仅读Subject3/4/5的正式block1-4，练习不纳入；原始数据不修改。
% 每人先独立计算，组均值等权，分母0返回NaN；不合并试次计算组比例。
% 图按目标自由C3/C5、手自由C6/C4、双自由C7/C8分面，统一Hand-first在左。
% 参考Endpoint_error的横排布局、蓝橙柱、浅网格和统一字体。
% 黑色小菱形为个体，无抖动；黑色细线连接同一被试同一实际手的两个顺序。
% 无SEM误差线、无模型拟合或统计检验。50%仅是左右各半参考。
% MATLAB R2016b+；无需统计工具箱或运行实验；不依赖其他.m文件。
if nargin<1 || isempty(dataDir)
    scriptDir=fileparts(mfilename('fullpath'));
    dataDir=fullfile(scriptDir,'data');
    if exist(dataDir,'dir')~=7
        dataDir='D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\data';
    end
end
if nargin<2 || isempty(outputDir)
    outputDir=fullfile(fileparts(dataDir),'SideChoice_ChoiceAnalysis');
end
assert(exist(dataDir,'dir')==7, '数据目录不存在：%s', dataDir);
if ~exist(outputDir,'dir'), mkdir(outputDir); end
subjects = [3 4 5];
allTrials = table(); sourceFiles = cell(12,1); kfile = 0;
countRows = cell(24,10); sideRows = cell(24,10); kr = 0;
required = {'plannedTrial','attemptNumber','cue1','cue2','responseHand', ...
    'responseTarget','handCorrect','targetCorrect','bothMoved','trialValid', ...
    'trialNote','leftReleaseX','leftReleaseY','rightReleaseX','rightReleaseY'};
for isub = 1:numel(subjects)
    sid = subjects(isub); subjectTrials = table();
    for block = 1:4
        % 精确指定文件名：不会读练习、个人信息或其他被试。
        fn = fullfile(dataDir,sprintf('Subject%d',sid),sprintf('Subject%d_block%d.mat',sid,block));
        assert(exist(fn,'file')==2,'缺少正式 block 文件：%s',fn);
        S = load(fn,'trial','config');
        assert(isfield(S,'trial') && istable(S.trial) && isfield(S,'config') && istable(S.config), ...
            '文件必须包含 trial/config table：%s',fn);
        T = S.trial; cfg = S.config;
        assert(all(ismember(required,T.Properties.VariableNames)),'字段不完整：%s',fn);
        assert(height(cfg)==1,'config 应只有一行');
        assert(strcmp(char(cfg.subjectID(1)),sprintf('Subject%d',sid)), '被试 ID 与文件不一致');
        assert(cfg.currentBlock(1)==block,'block 编号不一致');
        assert(all(ismember(double(T.trialValid),[0 1])),'trialValid 含未知编码');
        assert(all(isfinite(T.plannedTrial) & T.plannedTrial>=1 & T.plannedTrial==fix(T.plannedTrial)), ...
            'plannedTrial 缺失或不为正整数');
        assert(all(isfinite(T.attemptNumber) & T.attemptNumber>=1 & T.attemptNumber==fix(T.attemptNumber)), ...
            'attemptNumber 缺失或不为正整数');
        q1 = textColumn(T.cue1); q2 = textColumn(T.cue2);
        hand = textColumn(T.responseHand); target = textColumn(T.responseTarget);
        assert(all(ismember(hand,{'左手','右手','未完成'})), '未知实际手编码');
        assert(all(ismember(target,{'左目标','右目标','未完成'})), '未知实际目标编码');
        condition = decodeCondition(q1,q2);
        % 原始数据不含 condition；严格根据实际 cue 顺序/内容推导。
        for j = 1:numel(unique(T.plannedTrial))
            ids = unique(T.plannedTrial); ix = T.plannedTrial==ids(j);
            assert(numel(unique(condition(ix)))==1 && numel(unique(q1(ix)))==1 && numel(unique(q2(ix)))==1, ...
                '同一 plannedTrial 的重做 cue 改变');
            assert(numel(unique(T.attemptNumber(ix)))==sum(ix),'重复 attemptNumber');
        end
        instructedHand = ismember(q1,{'左手','右手'}) | ismember(q2,{'左手','右手'});
        instructedTarget = ismember(q1,{'左目标','右目标'}) | ismember(q2,{'左目标','右目标'});
        expectedHC = double(strcmp(hand,'右手')== (strcmp(q1,'右手') | strcmp(q2,'右手')));
        expectedTC = double(strcmp(target,'右目标')== (strcmp(q1,'右目标') | strcmp(q2,'右目标')));
        checkH = instructedHand & ismember(hand,{'左手','右手'});
        checkT = instructedTarget & ismember(target,{'左目标','右目标'});
        assert(all(T.handCorrect(checkH)==expectedHC(checkH)), 'handCorrect 与实际响应不一致');
        assert(all(T.targetCorrect(checkT)==expectedTC(checkT)), 'targetCorrect 与实际响应不一致');
        assert(all(isnan(T.handCorrect(~instructedHand))) && all(isnan(T.targetCorrect(~instructedTarget))), ...
            '自由选择正确性编码应为 NaN');
        known = ismember(hand,{'左手','右手'}) & ismember(target,{'左目标','右目标'});
        correct = (~instructedHand | T.handCorrect==1) & (~instructedTarget | T.targetCorrect==1);
        valid = T.trialValid==1 & known & correct & T.bothMoved==0;
        if any(T.trialValid==1 & ~valid)
            warning('ChoiceAnalysis:InconsistentValid','%s 存在有效标记但编码/正确性不一致；已排除并记录。',fn);
        end
        % 几何核验：目标是固定空间位置，而非颜色；不新增分析维度。
        X = T.rightReleaseX; Y = T.rightReleaseY; lh = strcmp(hand,'左手');
        X(lh)=T.leftReleaseX(lh); Y(lh)=T.leftReleaseY(lh);
        targetX = cfg.screenWidthPx(1)/2 + cfg.targetOffsetXPx(1)*ones(height(T),1);
        targetX(strcmp(target,'左目标'))=cfg.screenWidthPx(1)/2-cfg.targetOffsetXPx(1);
        targetY = cfg.screenHeightPx(1)/2-cfg.targetOffsetYPx(1);
        assert(all(hypot(X(valid)-targetX(valid),Y(valid)-targetY)<=cfg.targetResponseRadiusPx(1)+1e-6), ...
            '有效响应与目标空间位置不一致');
        if all(ismember({'cue1Onset','cue2Onset','goOnset'},T.Properties.VariableNames))
            assert(all(T.cue1Onset<T.cue2Onset & T.cue2Onset<T.goOnset),'cue 时间顺序错误');
        end
        assert(numel(unique(T.plannedTrial))==cfg.nTrials(1),'计划试次不完整');
        % 每个计划试次最多一个成功记录；不合并或重复计算失败尝试。
        assert(numel(unique(T.plannedTrial(valid)))==sum(valid),'同一计划试次有多个有效响应');
        A = table(repmat(sid,height(T),1),repmat(block,height(T),1),T.plannedTrial,T.attemptNumber, ...
            condition,q1,q2,hand,target,double(T.trialValid),known,correct,valid,T.bothMoved,textColumn(T.trialNote), ...
            'VariableNames',{'SubjectID','Block','PlannedTrial','AttemptNumber','Condition','Cue1','Cue2', ...
            'ResponseHand','ResponseTarget','RecordedValid','KnownResponse','CorrectRequirements','AnalysisValid','BothMoved','TrialNote'});
        if isempty(subjectTrials), subjectTrials=A; else, subjectTrials=[subjectTrials;A]; end %#ok<AGROW>
        kfile=kfile+1; sourceFiles{kfile}=fn;
    end
    D=subjectTrials;
    for c=1:8
        kr=kr+1; ix=D.Condition==c; v=ix & D.AnalysisValid;
        planned=size(unique([D.Block(ix) D.PlannedTrial(ix)],'rows'),1);
        expected=[80 80 40 40 40 40 40 40];
        assert(planned==expected(c),'计划条件数不符合实验设计');
        countRows(kr,:)={sid,sprintf('C%d',c),sum(ix),sum(ix & D.AttemptNumber==1),planned, ...
            sum(ix & D.RecordedValid==1),sum(v),sum(ix)-sum(v),sum(ix & D.RecordedValid==1 & ~D.AnalysisValid), ...
            sum(ix & ~D.KnownResponse)};
        sideRows(kr,:)={sid,sprintf('C%d',c),sum(v & strcmp(D.ResponseHand,'左手')),sum(v & strcmp(D.ResponseHand,'右手')), ...
            sum(v & strcmp(D.ResponseTarget,'左目标')),sum(v & strcmp(D.ResponseTarget,'右目标')), ...
            sum(ix & (strcmp(D.Cue1,'左手') | strcmp(D.Cue2,'左手'))), ...
            sum(ix & (strcmp(D.Cue1,'右手') | strcmp(D.Cue2,'右手'))), ...
            sum(ix & (strcmp(D.Cue1,'左目标') | strcmp(D.Cue2,'左目标'))), ...
            sum(ix & (strcmp(D.Cue1,'右目标') | strcmp(D.Cue2,'右目标')))};
    end
    if isempty(allTrials),allTrials=D;else,allTrials=[allTrials;D];end %#ok<AGROW>
end
counts=cell2table(countRows,'VariableNames',{'SubjectID','Condition','RawAttempts','InitialAttempts','UniquePlannedTrials', ...
    'RecordedValidAttempts','ValidTrials','ExcludedAttempts','InconsistentValidFlags','MissingResponseAttempts'});
sides=cell2table(sideRows,'VariableNames',{'SubjectID','Condition','ValidLeftHand','ValidRightHand','ValidLeftTarget','ValidRightTarget', ...
    'RawInstructedLeftHand','RawInstructedRightHand','RawInstructedLeftTarget','RawInstructedRightTarget'});
% 保留原脚本的按手条件化指标；仅重排展示顺序，使三个面板一致。
panelConditions=[3 5;6 4;7 8];
conditionList=[3 5 6 4 7 8];
panelTitles={'Free target','Free hand','Both free'};
panelSubtitles={'Hand instructed','Target instructed','Hand and target free'};
orderNames={'Hand-first','Target-first'};
responseHands={'Left hand','Right hand'};
probabilityLabels={'P(LT|LH)','P(RT|RH)'};
P=nan(numel(subjects),6,2);numer=zeros(numel(subjects),6,2);denom=zeros(numel(subjects),6,2);
individualRows=cell(numel(subjects)*6*2,9);k=0;
for s=1:numel(subjects)
    T=allTrials(allTrials.SubjectID==subjects(s) & allTrials.AnalysisValid,:);
    for j=1:6
        c=conditionList(j);idx=T.Condition==c;
        for h=1:2
            if h==1
                mask=idx & strcmp(T.ResponseHand,'左手');same=strcmp(T.ResponseTarget,'左目标');
            else
                mask=idx & strcmp(T.ResponseHand,'右手');same=strcmp(T.ResponseTarget,'右目标');
            end
            n=sum(mask & same);d=sum(mask);pct=NaN;
            if d>0,pct=100*n/d;end
            P(s,j,h)=pct;numer(s,j,h)=n;denom(s,j,h)=d;k=k+1;
            panel=ceil(j/2);ord=mod(j-1,2)+1;
            individualRows(k,:)={subjects(s),sprintf('C%d',c),panelTitles{panel},orderNames{ord}, ...
                responseHands{h},probabilityLabels{h},pct,n,d};
        end
    end
end
individual=cell2table(individualRows,'VariableNames',{'SubjectID','Condition','ChoiceContext','Order', ...
    'ResponseHand','ProbabilityLabel','SameSidePercent','Numerator','Denominator'});
groupRows=cell(12,11);means=nan(6,2);k=0;
for j=1:6
    for h=1:2
        [mu,sd,se,n]=describe(P(:,j,h));means(j,h)=mu;k=k+1;
        groupRows(k,:)={sprintf('C%d',conditionList(j)),panelTitles{ceil(j/2)},orderNames{mod(j-1,2)+1}, ...
            responseHands{h},probabilityLabels{h},n,mu,sd,se,sum(numer(:,j,h)),sum(denom(:,j,h))};
    end
end
group=cell2table(groupRows,'VariableNames',{'Condition','ChoiceContext','Order','ResponseHand','ProbabilityLabel', ...
    'NSubjects','MeanSameSidePercent','SD','SEM','TotalNumeratorAuditOnly','TotalDenominatorAuditOnly'});
% 保存配对描述性差值；固定实际响应手，只比较同一面板内的顺序条件。
pairedRows=cell(numel(subjects)*3*2,8);k=0;
for s=1:numel(subjects)
    for panel=1:3
        jj=(panel-1)*2+(1:2);
        for h=1:2
            k=k+1;v1=P(s,jj(1),h);v2=P(s,jj(2),h);
            pairedRows(k,:)={subjects(s),panelTitles{panel},responseHands{h}, ...
                sprintf('C%d',panelConditions(panel,1)),sprintf('C%d',panelConditions(panel,2)),v1,v2,v2-v1};
        end
    end
end
paired=cell2table(pairedRows,'VariableNames',{'SubjectID','ChoiceContext','ResponseHand','HandFirstCondition', ...
    'TargetFirstCondition','HandFirstPercent','TargetFirstPercent','TargetFirstMinusHandFirstPP'});
% ============================================================
% 图：三个横排面板，每个条件包含左手/右手两根柱；同色始终表示同一只手。
% 使用显式柱中心，避免依赖较新MATLAB的XEndPoints或yline。
% ============================================================
f=figure('Color','w','Units','pixels','Position',[50 100 1540 560], ...
    'MenuBar','none','ToolBar','none','Name','Side choice: Subjects 3-5','NumberTitle','off');
colors=[116 175 219;239 157 110]/255;
xGroups=[1 2.1];handOffsets=[-0.19 0.19];barWidth=0.30;
for panel=1:3
    ax=axes('Parent',f,'Units','normalized','Position',[0.065+(panel-1)*0.315 0.20 0.275 0.60]);
    hold(ax,'on');jj=(panel-1)*2+(1:2);barHandles=gobjects(2,1);
    for gy=[25 75 100]
        plot(ax,[0.50 2.60],[gy gy],'-','Color',[0.93 0.94 0.95],'LineWidth',0.65);
    end
    for h=1:2
        centers=xGroups+handOffsets(h);
        for ord=1:2
            yy=means(jj(ord),h);
            bh=bar(ax,centers(ord),yy,barWidth,'FaceColor',colors(h,:),'EdgeColor','none');
            if ord==1,barHandles(h)=bh;end
            if isfinite(yy)
                plot(ax,[centers(ord)-barWidth/2 centers(ord)-barWidth/2 centers(ord)+barWidth/2 centers(ord)+barWidth/2], ...
                    [0 yy yy 0],'-','Color',[0 0 0],'LineWidth',0.8);
            end
        end
    end
    plot(ax,[0.50 2.60],[50 50],'--','Color',[0.60 0.60 0.60],'LineWidth',0.8);
    % 不跨左/右手连线：仅连接同一被试同一实际手在两个cue顺序下的概率。
    for h=1:2
        centers=xGroups+handOffsets(h);
        for s=1:numel(subjects)
            vals=reshape(P(s,jj,h),1,2);
            plot(ax,centers,vals,'-','Color',[0 0 0],'LineWidth',0.55);
        end
    end
    for h=1:2
        centers=xGroups+handOffsets(h);
        for s=1:numel(subjects)
            plot(ax,centers,reshape(P(s,jj,h),1,2),'d','LineStyle','none', ...
                'MarkerSize',4.8,'MarkerFaceColor',[0 0 0],'MarkerEdgeColor',[0 0 0],'Clipping','off');
        end
    end
    tickLabels={sprintf('Hand-first (C%d)',panelConditions(panel,1)), ...
        sprintf('Target-first (C%d)',panelConditions(panel,2))};
    set(ax,'XLim',[0.50 2.60],'YLim',[0 100],'XTick',xGroups,'XTickLabel',tickLabels, ...
        'YTick',0:25:100,'FontName','Arial','FontSize',11,'LineWidth',0.85, ...
        'TickDir','out','TickLength',[0 0],'Box','off','Layer','top', ...
        'XColor',[0.2 0.2 0.2],'YColor',[0.2 0.2 0.2]);
    if isprop(ax,'XTickLabelRotation'),ax.XTickLabelRotation=0;end
    if panel==1,ylabel(ax,'Same-side choice by response hand (%)','FontSize',12);end
    title(ax,panelTitles{panel},'FontName','Arial','FontSize',14,'FontWeight','bold');
    % 选择约束另列为面板副标题，保持cue顺序与自由维度可识别。
    annotation(f,'textbox',[0.065+(panel-1)*0.315 0.875 0.275 0.04], ...
        'String',panelSubtitles{panel},'HorizontalAlignment','center', ...
        'EdgeColor','none','FontName','Arial','FontSize',10,'Color',[0.40 0.40 0.40]);
    if panel==1
        lg=legend(ax,barHandles,{'Left hand: P(LT|LH)','Right hand: P(RT|RH)'}, ...
            'Orientation','horizontal','Box','off','FontName','Arial','FontSize',10);
        drawnow;set(lg,'Units','normalized','Position',[0.30 0.94 0.42 0.045]);
        if isprop(lg,'AutoUpdate'),lg.AutoUpdate='off';end
    end
    if isprop(ax,'Toolbar'),ax.Toolbar.Visible='off';end
end
annotation(f,'textbox',[0.12 0.045 0.78 0.05],'String', ...
    'Dashed line: 50% reference (equal left/right target proportions within each response hand).', ...
    'HorizontalAlignment','center','EdgeColor','none','FontName','Arial','FontSize',10,'Color',[0.4 0.4 0.4]);
set(f,'PaperPositionMode','auto');
print(f,fullfile(outputDir,'Subject3to5_SideChoice_ChoiceAnalysis.png'),'-dpng','-r300');
savefig(f,fullfile(outputDir,'Subject3to5_SideChoice_ChoiceAnalysis.fig'));
results=struct('subjects',subjects,'conditions',conditionList,'panelConditions',panelConditions, ...
    'percent',P,'numerator',numer,'denominator',denom,'individual',individual, ...
    'group',group,'paired',paired,'counts',counts,'trialAudit',allTrials,'sourceFiles',{sourceFiles}, ...
    'dataDir',dataDir,'outputDir',outputDir);
writetable(individual,fullfile(outputDir,'Subject3to5_SideChoice_Individual_ChoiceAnalysis.csv'));
writetable(group,fullfile(outputDir,'Subject3to5_SideChoice_Group_ChoiceAnalysis.csv'));
writetable(paired,fullfile(outputDir,'Subject3to5_SideChoice_Paired_ChoiceAnalysis.csv'));
writetable(counts,fullfile(outputDir,'Subject3to5_SideChoice_Counts_ChoiceAnalysis.csv'));
save(fullfile(outputDir,'Subject3to5_SideChoice_Results_ChoiceAnalysis.mat'),'results','-v7');
fid=fopen(fullfile(outputDir,'Subject3to5_SideChoice_Notes_ChoiceAnalysis.txt'),'w','n','UTF-8');
assert(fid>=0,'无法保存说明文件');cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'本代码保留原Choice_side_plot指标：左手P(LT|LH)，右手P(RT|RH)，不是总体同侧比例。\n');
fprintf(fid,'分析Subject3-5正式block1-4，实际响应，trialValid成功试次；自由维度正确性NaN不排除。\n');
fprintf(fid,'分母是当前条件实际用左手/右手的有效次数；0分母NaN。组均值先按人计算再等权平均。\n');
fprintf(fid,'面板为目标自由C3/C5、手自由C6/C4、双自由C7/C8；各面板均Hand-first在左，Target-first在右。\n');
fprintf(fid,'同色柱始终表示相同响应手；黑点黑线为同一被试同一响应手的顺序配对，无抖动。\n');
fprintf(fid,'不按规划时长增加分组：Endpoint_error仅作视觉参考。50%%只是左右各半参考。\n');
fprintf(fid,'手自由/双自由条件按实际手筛选可能改变试次组成；左右偏好可影响同侧条件概率。\n');
fprintf(fid,'本次仅描述性汇总，不检验因果关系，不推断自发手/目标决策先后顺序。\n');
disp(individual);disp(group);fprintf('Subject3-5按手同侧比例已保存：%s\n',outputDir);
end

function c=textColumn(x)
% 兼容 string、cellstr 和字符矩阵；不猜测未知编码。
if iscell(x),c=x(:);elseif ischar(x),c=cellstr(x);else,c=cellstr(x);end
assert(all(cellfun(@ischar,c)), '文本字段包含非字符单元');
end

function condition=decodeCondition(q1,q2)
H=ismember(q1,{'左手','右手'});T=ismember(q1,{'左目标','右目标'});
H2=ismember(q2,{'左手','右手'});T2=ismember(q2,{'左目标','右目标'});
condition=zeros(numel(q1),1);
condition(H & T2)=1;condition(T & H2)=2;
condition(H & strcmp(q2,'自由目标'))=3;condition(T & strcmp(q2,'自由手'))=4;
condition(strcmp(q1,'自由目标') & H2)=5;condition(strcmp(q1,'自由手') & T2)=6;
condition(strcmp(q1,'自由手') & strcmp(q2,'自由目标'))=7;
condition(strcmp(q1,'自由目标') & strcmp(q2,'自由手'))=8;
assert(all(condition>0),'发现无法映射到 C1-C8 的 cue 编码；请核实采集代码');
end

function [mu,sd,se,n]=describe(x)
x=x(isfinite(x));n=numel(x);mu=NaN;sd=NaN;se=NaN;
if n>0,mu=mean(x);end
if n>1,sd=std(x,0);se=sd/sqrt(n);end
end


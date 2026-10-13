function results = plot_Ipsilateral_ChoiceAnalysis(dataDir, outputDir)
% 各实验条件实际手—目标同侧比例：独立入口，无需旧分析脚本。
% 默认调用：results = plot_Ipsilateral_ChoiceAnalysis;
% 自定义：results = plot_Ipsilateral_ChoiceAnalysis('您的数据目录','您的输出目录');
% MATLAB R2016b+，无需统计工具箱或Psychtoolbox；不修改原始数据。
% 默认数据目录：D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\data
% 读取Subject3/4/5的正式block1-4，不读取practice或information。
% 实际同侧 = 左手到左目标 或 右手到右目标；分母为该条件有效次数。
% 分母为零时NaN；组均值等权；图不画SEM，不做推断或模型拟合。
% 面板顺序及条件（蓝=Hand-first，橙=Target-first）：
% 目标自由 C3/C5；手自由 C6/C4；双自由 C7/C8；双指定 C1/C2。
% C1/C2只反映指定组合的实际执行，不解释为自由选择偏好。
% 灰色0.5线只是同侧/异侧各半参考，不自动表示独立随机选择基线。
% 用户已确认实际采集版本与提供代码的分析相关定义一致。
if nargin < 1 || isempty(dataDir)
    dataDir = 'D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\data';
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(fileparts(dataDir), 'Ipsilateral_ChoiceAnalysis');
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
% 每名被试逐条件计算，不合并被试试次。
handMode={'Instructed','Instructed','Instructed','Free','Instructed','Free','Free','Free'};
targetMode={'Instructed','Instructed','Free','Instructed','Free','Instructed','Free','Free'};
orderNames={'Hand-first','Target-first','Hand-first','Target-first','Target-first','Hand-first','Hand-first','Target-first'};
P=nan(numel(subjects),8); numer=zeros(numel(subjects),8); denom=zeros(numel(subjects),8);
individualRows=cell(numel(subjects)*8,14); k=0;
for s=1:numel(subjects)
    D=allTrials(allTrials.SubjectID==subjects(s) & allTrials.AnalysisValid,:);
    for c=1:8
        T=D(D.Condition==c,:);
        LH=strcmp(T.ResponseHand,'左手'); RH=strcmp(T.ResponseHand,'右手');
        LT=strcmp(T.ResponseTarget,'左目标'); RT=strcmp(T.ResponseTarget,'右目标');
        ll=sum(LH & LT); rr=sum(RH & RT); lr=sum(LH & RT); rl=sum(RH & LT);
        n=ll+rr; d=height(T); value=NaN; pLH=NaN; pLT=NaN; independentReference=NaN;
        assert(ll+rr+lr+rl==d,'实际响应未完整分类');
        if d>0
            value=n/d; pLH=sum(LH)/d; pLT=sum(LT)/d;
            % 仅保存描述性的独立边际参考，非拟合/检验，也不画入图。
            % 左右偏好可使独立选择的同侧概率偏离0.5。
            independentReference=pLH*pLT+(1-pLH)*(1-pLT);
        end
        P(s,c)=value;numer(s,c)=n;denom(s,c)=d;k=k+1;
        individualRows(k,:)={subjects(s),sprintf('C%d',c),orderNames{c},handMode{c},targetMode{c}, ...
            value,n,d,ll,rr,lr,rl,pLH,pLT};
    end
end
individual=cell2table(individualRows,'VariableNames',{'SubjectID','Condition','Order','HandMode','TargetMode', ...
    'IpsilateralProportion','Numerator','Denominator','LeftHandLeftTarget','RightHandRightTarget', ...
    'LeftHandRightTarget','RightHandLeftTarget','PLeftHand','PLeftTarget'});
individual.IndependenceReference=individual.PLeftHand.*individual.PLeftTarget + ...
    (1-individual.PLeftHand).*(1-individual.PLeftTarget);
groupRows=cell(8,10);means=nan(1,8);
for c=1:8
    [mu,sd,se,n]=describe(P(:,c));means(c)=mu;
    groupRows(c,:)={sprintf('C%d',c),orderNames{c},handMode{c},targetMode{c},n,mu,sd,se, ...
        sum(numer(:,c)),sum(denom(:,c))};
end
group=cell2table(groupRows,'VariableNames',{'Condition','Order','HandMode','TargetMode','NSubjects', ...
    'MeanIpsilateralProportion','SD','SEM','TotalNumeratorAuditOnly','TotalDenominatorAuditOnly'});
% SEM仅存表供描述；不显示在图中。合计次数不参与等权均值计算。
panelConditions=[3 5;6 4;7 8;1 2];
panelTitles={'Target free','Hand free','Both free','Both instructed'};
panelRows=cell(8,5);k=0;
for panel=1:4
    for mode=1:2
        k=k+1;c=panelConditions(panel,mode);
        panelRows(k,:)={panelTitles{panel},sprintf('C%d',c),orderNames{c},handMode{c},targetMode{c}};
    end
end
panelMap=cell2table(panelRows,'VariableNames',{'Panel','Condition','Order','HandMode','TargetMode'});
% 论文风格绘图；所有面板按Hand-first→Target-first，颜色含义一致。
f=figure('Color','w','Units','pixels','Position',[60 100 1480 500], ...
    'MenuBar','none','ToolBar','none','Name','Ipsilateral ChoiceAnalysis','NumberTitle','off');
barColors=[116 175 219;239 157 110]/255;
xPositions=[1 1.8];barWidth=0.384;
for panel=1:4
    ax=axes('Parent',f,'Units','normalized', ...
        'Position',[0.065+(panel-1)*0.235 0.25 0.185 0.60]);hold(ax,'on');
    for gy=[0.25 0.75 1]
        plot(ax,[0.60 2.20],[gy gy],'-','Color',[0.94 0.94 0.94],'LineWidth',0.6);
    end
    cs=panelConditions(panel,:);
    for mode=1:2
        bar(ax,xPositions(mode),means(cs(mode)),barWidth,'FaceColor',barColors(mode,:),'EdgeColor','none');
        xx=xPositions(mode);yy=means(cs(mode));halfWidth=barWidth/2;
        if isfinite(yy)
            plot(ax,[xx-halfWidth xx-halfWidth xx+halfWidth xx+halfWidth], ...
                [0 yy yy 0],'-','Color',[0 0 0],'LineWidth',0.9);
        end
    end
    % 参考线绘于柱前，保证可见；0.5不是自动成立的随机选择基线。
    plot(ax,[0.60 2.20],[0.5 0.5],'--','Color',[0.60 0.60 0.60],'LineWidth',0.8);
    for s=1:numel(subjects)
        plot(ax,xPositions,P(s,cs),'-','Color',[0 0 0],'LineWidth',0.65);
    end
    for s=1:numel(subjects)
        plot(ax,xPositions,P(s,cs),'d','LineStyle','none','MarkerSize',5, ...
            'MarkerFaceColor',[0 0 0],'MarkerEdgeColor',[0 0 0],'Clipping','off');
    end
    tickLabels={sprintf('Hand-first\nC%d',cs(1)),sprintf('Target-first\nC%d',cs(2))};
    set(ax,'XLim',[0.60 2.20],'YLim',[0 1],'XTick',xPositions,'YTick',0:0.25:1, ...
        'XTickLabel',tickLabels,'FontName','Arial','FontSize',10.5,'Box','off', ...
        'TickDir','out','TickLength',[0 0],'LineWidth',0.8,'Layer','top', ...
        'XColor',[0.20 0.20 0.20],'YColor',[0.20 0.20 0.20]);
    if isprop(ax,'XTickLabelRotation'),ax.XTickLabelRotation=0;end
    if panel==1,ylabel(ax,'Ipsilateral choice proportion','FontSize',12);end
    if panel==4
        title(ax,{panelTitles{panel},'(execution only)'},'FontWeight','normal','FontSize',13);
    else
        title(ax,panelTitles{panel},'FontWeight','normal','FontSize',13);
    end
    if isprop(ax,'Toolbar'),ax.Toolbar.Visible='off';end
end
annotation(f,'textbox',[0.08 0.045 0.88 0.06], ...
    'String','Dashed line: equal same-side/opposite-side proportions (0.5); not necessarily a random-choice baseline.', ...
    'EdgeColor','none','HorizontalAlignment','center','FontName','Arial','FontSize',10,'Color',[0.4 0.4 0.4]);
set(f,'PaperPositionMode','auto');
print(f,fullfile(outputDir,'IpsilateralFigure_ChoiceAnalysis.png'),'-dpng','-r300');
savefig(f,fullfile(outputDir,'IpsilateralFigure_ChoiceAnalysis.fig'));
results=struct('subjects',subjects,'P',P,'numerator',numer,'denominator',denom, ...
    'individual',individual,'group',group,'counts',counts,'sideCounts',sides, ...
    'panelMap',panelMap,'trialAudit',allTrials,'sourceFiles',{sourceFiles}, ...
    'definition','Actual left hand-left target OR actual right hand-right target, divided by valid trials', ...
    'dataDir',dataDir,'outputDir',outputDir);
writetable(individual,fullfile(outputDir,'IpsilateralIndividual_ChoiceAnalysis.csv'));
writetable(group,fullfile(outputDir,'IpsilateralGroup_ChoiceAnalysis.csv'));
writetable(counts,fullfile(outputDir,'IpsilateralTrialCounts_ChoiceAnalysis.csv'));
writetable(sides,fullfile(outputDir,'IpsilateralSideCounts_ChoiceAnalysis.csv'));
writetable(panelMap,fullfile(outputDir,'IpsilateralPanelMap_ChoiceAnalysis.csv'));
writetable(allTrials,fullfile(outputDir,'IpsilateralTrialAudit_ChoiceAnalysis.csv'));
save(fullfile(outputDir,'IpsilateralResults_ChoiceAnalysis.mat'),'results','-v7');
fid=fopen(fullfile(outputDir,'IpsilateralNotes_ChoiceAnalysis.txt'),'w','n','UTF-8');
assert(fid>=0,'无法写入说明文件');cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'同侧比例=(左手左目标+右手右目标)/当前条件有效次数。每名被试先单独计算，组均值等权。\n');
fprintf(fid,'目标自由：C3/C5；手自由：C6/C4；双自由：C7/C8；双指定：C1/C2。均按Hand-first/Target-first排列。\n');
fprintf(fid,'C1/C2为指定组合执行参考，不代表自由选择偏好。不同面板的选择约束不同。\n');
fprintf(fid,'0.5线仅表示同侧/异侧各半；独立边际参考为P(LH)P(LT)+[1-P(LH)][1-P(LT)]，仅描述性保存。\n');
fprintf(fid,'图中柱高为等权均值；黑色菱形及连线为被试配对值；重合点不抖动，无SEM误差线。\n');
fprintf(fid,'本脚本仅作描述性呈现，无统计检验或模型拟合，不据此推断内部决策先后顺序。\n');
disp(individual);disp(group);fprintf('同侧比例输出已保存：%s\n',outputDir);
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


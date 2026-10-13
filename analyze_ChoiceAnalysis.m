function results = analyze_ChoiceAnalysis(dataDir, outputDir)
% 条件概率分析：Subject 3/4/5；仅比较 C3/C7 和 C4/C8。
% 用法（MATLAB R2016b 或更新；无需统计工具箱、Psychtoolbox）：
% results = analyze_ChoiceAnalysis;
% results = analyze_ChoiceAnalysis('D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\data', ...
%                                 'D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\ChoiceAnalysis');
% 原始 MAT 中的 trial/config 必须是 MATLAB table；不修改任何原始文件。
% 采集版本差异已由用户确认不影响 cue、实际响应编码及 trialValid 定义。
% 分母使用当前条件下固定手/目标的有效试次数；分母为零时返回 NaN。
% 原始次数包括失败/重做，计划试次数按 block+plannedTrial 去重。
% 试次有效性不同于 RT 分析；不再增加 RT 阈值、额外触点排除等筛选。
% 不执行计算模型拟合、模型选择或似然比检验。
if nargin < 1 || isempty(dataDir)
    dataDir = 'D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\data';
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(fileparts(dataDir), 'ChoiceAnalysis');
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
panels={'a','b','c','d'}; labels={'P(LT|LH)','P(LT|RH)','P(LH|LT)','P(LH|RT)'};
firstCue={'Hand','Hand','Target','Target'}; fixed={'Left Hand','Right Hand','Left Target','Right Target'};
conditions=[3 7;3 7;4 8;4 8]; modes={'Instructed','Free'};
P=nan(3,4,2); numer=zeros(3,4,2); denom=zeros(3,4,2); probRows=cell(24,10);k=0;
for s=1:3
    D=allTrials(allTrials.SubjectID==subjects(s) & allTrials.AnalysisValid,:);
    for panel=1:4
        for mode=1:2
            ix=D.Condition==conditions(panel,mode);
            if panel<=2
                choices={'左手','右手'}; ix=ix & strcmp(D.ResponseHand,choices{panel});
                hit=strcmp(D.ResponseTarget,'左目标');
            else
                choices={'左目标','右目标'}; ix=ix & strcmp(D.ResponseTarget,choices{panel-2});
                hit=strcmp(D.ResponseHand,'左手');
            end
            n=sum(ix & hit); d=sum(ix); value=NaN;
            if d>0,value=n/d;end
            P(s,panel,mode)=value;numer(s,panel,mode)=n;denom(s,panel,mode)=d;k=k+1;
            probRows(k,:)={subjects(s),panels{panel},sprintf('C%d',conditions(panel,mode)),firstCue{panel}, ...
                modes{mode},fixed{panel},labels{panel},value,n,d};
        end
    end
end
probabilities=cell2table(probRows,'VariableNames',{'SubjectID','Panel','Condition','FirstCue','FirstCueMode','FixedFirstChoice', ...
    'ProbabilityLabel','ConditionalProbability','Numerator','Denominator'});
groupRows=cell(8,9); diffRows=cell(12,8);statRows=cell(4,14);k=0;kd=0;
means=nan(4,2);sems=nan(4,2);
for panel=1:4
    for mode=1:2
        [mu,sd,se,n]=describe(P(:,panel,mode));means(panel,mode)=mu;sems(panel,mode)=se;k=k+1;
        groupRows(k,:)={panels{panel},sprintf('C%d',conditions(panel,mode)),labels{panel},modes{mode},n,mu,sd,se, ...
            sum(denom(:,panel,mode))}; % 分母合计仅供审计，不用于组均值
    end
    d=P(:,panel,2)-P(:,panel,1); % 统一 Free - Instructed
    for s=1:3
        kd=kd+1;diffRows(kd,:)={subjects(s),panels{panel},labels{panel}, ...
            sprintf('C%d',conditions(panel,1)),sprintf('C%d',conditions(panel,2)),P(s,panel,1),P(s,panel,2),d(s)};
    end
    good=d(isfinite(d));[mu,sd,se,n]=describe(good);
    if isempty(good), med=NaN;lo=NaN;hi=NaN; else, med=median(good);lo=min(good);hi=max(good);end
    [pv,nt]=exactSignFlip(good);
    statRows(panel,:)={panels{panel},labels{panel},n,mu,sd,se,med,lo,hi,sum(good>0),sum(good<0),sum(good==0),pv,nt};
end
group=cell2table(groupRows,'VariableNames',{'Panel','Condition','ProbabilityLabel','FirstCueMode','NSubjects','Mean','SD','SEM','TotalDenominatorAuditOnly'});
differences=cell2table(diffRows,'VariableNames',{'SubjectID','Panel','ProbabilityLabel','InstructedCondition','FreeCondition', ...
    'InstructedProbability','FreeProbability','DifferenceFreeMinusInstructed'});
statistics=cell2table(statRows,'VariableNames',{'Panel','ProbabilityLabel','NPairedSubjects','MeanDifference','SDDifference', ...
    'SEMDifference','MedianDifference','MinDifference','MaxDifference','NPositive','NNegative','NZero','ExactTwoSidedP','NFlips'});
statistics.HolmAdjustedP=holm(statistics.ExactTwoSidedP);
% 精确符号翻转：独立被试，零假设下各被试配对差值可独立翻转符号
% （差值分布关于零对称/条件标签可交换）；枚举全部 2^n 个符号组合。
% n=3 时双侧 p 最小为 2/8=0.25；无需 +1 校正（这是完整枚举）。
% 对四项检验作 Holm 家族错误率校正；仅作探索证据。
% 不显著不表示等价；不把试次当作独立被试；不推断自发选择先后顺序。
f=figure('Color','w','Position',[80 80 1100 760]);colors=[0.20 0.45 0.68;0.80 0.40 0.22;0.38 0.60 0.38];
for panel=1:4
    ax=subplot(2,2,panel);hold(ax,'on');h=[];
    % SEM 小幅横向错开，个体点仍位于真实两条件位置。
    errorbar(ax,[1.06 2.06],means(panel,:),sems(panel,:),'LineStyle','none','Color',[0.25 0.25 0.25],'LineWidth',1);
    for s=1:3
        hh=plot(ax,[1 2],reshape(P(s,panel,:),1,2),'-o','Color',colors(s,:), ...
            'LineWidth',0.9,'MarkerSize',6,'MarkerFaceColor','w'); h=[h hh]; %#ok<AGROW>
    end
    hh=plot(ax,[1 2],means(panel,:),'-d','Color',[0.05 0.05 0.05],'LineWidth',2.3,'MarkerSize',8, ...
        'MarkerFaceColor',[0.05 0.05 0.05]);h=[h hh]; %#ok<AGROW>
    set(ax,'XLim',[0.7 2.3],'YLim',[0 1],'XTick',[1 2],'YTick',0:0.2:1, ...
        'XTickLabel',{'First Cue Instructed','First Cue Free'},'FontName','Arial','FontSize',10,'Box','off','TickDir','out');
    ylabel(ax,'Conditional probability');title(ax,sprintf('%s  %s | Fixed: %s',panels{panel},labels{panel},fixed{panel}), ...
        'FontWeight','normal','Interpreter','none');
    if panel==1,legend(h,{'Subject 3','Subject 4','Subject 5','Subject mean'},'Location','best','Box','off');end
end
set(f,'PaperPositionMode','auto');
print(f,fullfile(outputDir,'Figure_ChoiceAnalysis.png'),'-dpng','-r300');
savefig(f,fullfile(outputDir,'Figure_ChoiceAnalysis.fig'));
results=struct('counts',counts,'sideCounts',sides,'probabilities',probabilities,'group',group, ...
    'differences',differences,'statistics',statistics,'trialAudit',allTrials,'P',P,'numerator',numer,'denominator',denom, ...
    'sourceFiles',{sourceFiles},'differenceDirection','Free minus Instructed', ...
    'inferenceAssumption','Independent subjects; sign exchangeability of paired differences under the null', ...
    'dataDir',dataDir,'outputDir',outputDir);
writetable(counts,fullfile(outputDir,'TrialCounts_ChoiceAnalysis.csv'));
writetable(sides,fullfile(outputDir,'SideCounts_ChoiceAnalysis.csv'));
writetable(probabilities,fullfile(outputDir,'IndividualProbabilities_ChoiceAnalysis.csv'));
writetable(group,fullfile(outputDir,'GroupProbabilities_ChoiceAnalysis.csv'));
writetable(differences,fullfile(outputDir,'PairedDifferences_ChoiceAnalysis.csv'));
writetable(statistics,fullfile(outputDir,'Statistics_ChoiceAnalysis.csv'));
writetable(allTrials,fullfile(outputDir,'TrialAudit_ChoiceAnalysis.csv'));
save(fullfile(outputDir,'Results_ChoiceAnalysis.mat'),'results','-v7');
fid=fopen(fullfile(outputDir,'Summary_ChoiceAnalysis.txt'),'w','n','UTF-8');
assert(fid>=0,'无法创建总结文件');cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'条件概率分析；差值统一为 Free - Instructed。组平均为被试等权平均。\n');
for panel=1:4
    fprintf(fid,'Panel %s %s：指定 %.6f，自由 %.6f；差值 %.6f，SEM %.6f；正/负/零 %d/%d/%d。\n', ...
        panels{panel},labels{panel},means(panel,1),means(panel,2),statistics.MeanDifference(panel), ...
        statistics.SEMDifference(panel),statistics.NPositive(panel),statistics.NNegative(panel),statistics.NZero(panel));
end
fprintf(fid,'精确双侧符号翻转检验，以独立被试和零假设下差值符号可交换为假设；四项 Holm 校正。\n');
fprintf(fid,'仅3名被试，推断属探索性；不显著不表示等价，不能据此推断自发选择手/目标的先后顺序。\n');
fprintf(fid,'分析以实际最终响应固定第一 cue 结果；该结果不是第一 cue 当下决策完成的时间证据。\n');
disp(statistics);fprintf('ChoiceAnalysis 输出已保存：%s\n',outputDir);
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

function [p,nt]=exactSignFlip(d)
d=d(isfinite(d));n=numel(d);p=NaN;nt=0;if n==0,return;end
nt=2^n;flipped=zeros(nt,1);
for k=0:nt-1
    signs=ones(n,1);for j=1:n,if bitget(k,j)==0,signs(j)=-1;end,end
    flipped(k+1)=abs(mean(d(:).*signs));
end
observed=abs(mean(d));p=sum(flipped>=observed-1e-12)/nt;
end

function adjusted=holm(p)
% 预先定义四项比较；若缺失检验，则按 p=1 留在校正家族中。
q=p;q(~isfinite(q))=1;[v,idx]=sort(q);m=numel(q);out=zeros(m,1);running=0;
for j=1:m,running=max(running,(m-j+1)*v(j));out(j)=min(1,running);end
adjusted=zeros(m,1);adjusted(idx)=out;adjusted(~isfinite(p))=NaN;
end

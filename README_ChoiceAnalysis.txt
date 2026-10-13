ChoiceAnalysis 使用说明

1. 把 analyze_ChoiceAnalysis.m 放在 MATLAB 工作目录或加入 MATLAB 路径。
2. 默认执行：results = analyze_ChoiceAnalysis;
   默认输入 D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\data
   默认输出 D:\Postgraduate\iEEG_code\New_analysis\LQT_exp\ChoiceAnalysis
3. 或显式设置输入/输出：
   results = analyze_ChoiceAnalysis('您的数据目录','您的输出目录');
4. 数据目录内应有 Subject3、Subject4、Subject5 子目录，各含 SubjectN_block1.mat 至 block4.mat。
5. MATLAB R2016b+；不需要统计工具箱，不需要运行原始实验或安装Psychtoolbox。
6. 输出会覆盖输出目录中的同名分析文件，不修改原始数据。

output 是已实际计算并经独立交叉表核验的结果。中文总结见 output/Summary_ChoiceAnalysis.md。
本环境无MATLAB，MATLAB原生运行及FIG打开尚未验证。
当前FIG为传统hgS_070000图形树格式；若版本不兼容，运行上述MATLAB代码重建原生FIG。
PNG 300dpi；另提供可编辑SVG。MAT输出来自Python独立计算，结果表存为列结构体；
MATLAB运行后的MAT中results保存table。两者概率、差值、SEM、精确p和Holm p定义相同。

sourceFiles/hash对应上传原始MAT，不含模拟数据。分析仅用正式block，不含练习。
四项比较是C3/C7的P(LT|LH)、P(LT|RH)，C4/C8的P(LH|LT)、P(LH|RT)。
差值=Free-Instructed。缺失分母返回NaN；均值等权；SEM基于有效被试数。
符号翻转检验的假设、n=3局限性、Holm多重比较及解释限制详见中文总结。

verification 包含Python独立复核程序。安装numpy/scipy/pandas/matplotlib后，
将data.zip解压为与程序所在目录相邻的data/，运行run_ChoiceAnalysis.py。
其中MCOS读取只适用于本次已检查的MAT布局；未知布局会报错，不猜测列名。

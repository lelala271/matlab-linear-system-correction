function results=run_experiment
% 线性系统串联校正实验：从真实RC运放电路仿真到图件、数据和指标。
% 直接点击运行本文件：建立两份SLX电路、计算原系统及三组超前校正、
% 测量阶跃/方波响应，并在“结果”文件夹输出PNG、CSV、MAT和实验小结。
% 需要 MATLAB、Simulink、Simscape、Control System Toolbox。
% 所有运放采用理想模型，所给波形均为仿真测量，未模拟实物非理想因素。
rootDir=fileparts(mfilename('fullpath')); addpath(rootDir);
outDir=fullfile(rootDir,'结果'); if ~isfolder(outDir), mkdir(outDir); end
oldCfg=Simulink.fileGenControl('getConfig');
cacheDir=fullfile(tempdir,'linear_system_correction_cache');
Simulink.fileGenControl('set','CacheFolder',fullfile(cacheDir,'cache'), ...
    'CodeGenFolder',fullfile(cacheDir,'codegen'),'createDir',true);
restoreCfg=onCleanup(@() Simulink.fileGenControl('setConfig','config',oldCfg)); %#ok<NASGU>
s=tf('s'); plant=20/(s*(0.5*s+1));
model0=build_circuit(rootDir,false); model1=build_circuit(rootDir,true);
caseNames={'未校正','超前校正：Cf=0.30 µF','超前校正：Cf=0.25 µF（主方案）','超前校正：Cf=0.20 µF'};
Tlist=[NaN 0.030 0.025 0.020];
results=struct('plant',plant,'stepTime',0.1,'stepAmplitude',1, ...
    'sampleTime',0.0005,'sourceFilterTime',1e-4,'modelAssumption','理想运放、理想RC元件，零初始状态');
for k=1:4
 if k==1
  model=model0; gc=tf(1); cf=NaN;
 else
  model=model1; cf=Tlist(k)/100e3;
  set_param([model '/C2_feedback'],'c',num2str(cf,16));
  gc=(0.5*s+1)/(Tlist(k)*s+1);
 end
 fprintf('正在运行第%d/4组：%s\n',k,caseNames{k});
 d=simulate(model,false,8.1,0.001,0.0005);
 q=struct('name',caseNames{k},'T',Tlist(k),'Cf',cf,'controller',gc, ...
     't',d.Time,'r',d.Data(:,1),'y',d.Data(:,5),'internal',d.Data(:,2:6));
 q.closedLoop=minreal(feedback(gc*plant,1),1e-9);
 assert(all(real(pole(q.closedLoop))<0),'闭环不稳定。');
 q.Kv=dcgain(minreal(s*gc*plant,1e-9));
 mask=q.t>=results.stepTime; tr=q.t(mask)-results.stepTime;
 q.theory=zeros(size(q.t)); q.theory(mask)=step(q.closedLoop/(results.sourceFilterTime*s+1),tr);
 q.tfMaxError=max(abs(q.y-q.theory));
 q.metrics=stepinfo(q.y(mask),tr,1,'SettlingTimeThreshold',0.02);
 five=stepinfo(q.y(mask),tr,1,'SettlingTimeThreshold',0.05);
 q.settling5percent=five.SettlingTime;
 if k==1, tau=0.5; else, tau=Tlist(k); end
 q.wn=sqrt(20/tau); q.zeta=1/(2*sqrt(20*tau));
 q.theoryOvershoot=100*exp(-pi*q.zeta/sqrt(1-q.zeta^2));
 q.theoryPeakTime=pi/(q.wn*sqrt(1-q.zeta^2));
 results.cases(k)=q;
 fprintf('  Mp=%.5f%%, ts(2%%)=%.5f s, Kv=%.3f, 电路/理论最大差=%.3g V\n', ...
     q.metrics.Overshoot,q.metrics.SettlingTime,q.Kv,q.tfMaxError);
end
% 主方案恢复到Cf=0.25µF，再用减半最大步长复算，检查求解器误差。
set_param([model1 '/C2_feedback'],'c','2.5e-7');
fine=simulate(model1,false,8.1,0.0005,0.0005);
coarse=results.cases(3);
results.refinement.maxError=max(abs(interp1(fine.Time,fine.Data(:,5),coarse.t)-coarse.y));
results.refinement.maxStep=[0.001 0.0005];
% 指导书的10s周期方波：明确选用0~1V、50%占空比，0.1s首次跳变。
for k=1:2
 if k==1, model=model0; else, model=model1; end
 fprintf('正在测量10s周期方波：%s\n',model);
 d=simulate(model,true,20.1,0.001,0.001);
 results.square(k).t=d.Time; results.square(k).r=d.Data(:,1);
 results.square(k).y=d.Data(:,5);
end
% 保存模型时选择阶跃输入，主方案参数固定，方便打开SLX后直接点运行。
for model={model0,model1}
 m=model{1}; set_param([m '/Input_select'],'sw','1');
 set_param(m,'StopTime','8.1','MaxStep','0.001','OutputTimes','0:0.0005:8.1');
 save_system(m,fullfile(rootDir,[m '.slx']));
end
save(fullfile(outDir,'仿真数据.mat'),'results','-v7');
exportTables(results,outDir);
plot_experiment(results,outDir);
writeSummary(results,outDir);
verify_experiment(rootDir);
fprintf('\n全部完成。电路模型：%s\n图件与数据：%s\n',rootDir,outDir);
end

function d=simulate(model,isSquare,stopTime,maxStep,dt)
% 电压源→RC/运放物理电路→电压传感器；并非用传递函数代替电路仿真。
if isSquare, sw='0'; else, sw='1'; end
set_param([model '/Input_select'],'sw',sw);
set_param(model,'StopTime',num2str(stopTime,16),'MaxStep',num2str(maxStep,16), ...
    'OutputTimes',sprintf('0:%.16g:%.16g',dt,stopTime));
z=sim(model); raw=z.measurements;
% 求解器可能在跳变处记录同一时刻的左右极限，取最后一个作为右极限。
[time,idx]=unique(raw.Time,'last'); d=timeseries(raw.Data(idx,:),time);
assert(size(d.Data,2)==6,'电压测量通道数不正确。');
end

function exportTables(z,outDir)
% 表中的动态指标来自电路波形，所有时间均减去0.1s阶跃发生时刻。
n=numel(z.cases); names=strings(n,1); Cf=zeros(n,1); Mp=Cf; ts2=Cf; ts5=Cf; tp=Cf; Kv=Cf; error=Cf;
for k=1:n
 q=z.cases(k); names(k)=q.name; Cf(k)=q.Cf*1e6; Mp(k)=q.metrics.Overshoot;
 ts2(k)=q.metrics.SettlingTime; ts5(k)=q.settling5percent;
 tp(k)=q.metrics.PeakTime; Kv(k)=q.Kv; error(k)=q.tfMaxError;
end
tab=table(names,Cf,Mp,ts2,ts5,tp,Kv,error,'VariableNames', ...
    {'方案','反馈电容_uF','超调量_pct','调节时间2pct_s','调节时间5pct_s','峰值时间_s','Kv_每秒','电路理论最大差_V'});
writetable(tab,fullfile(outDir,'性能指标.csv'),'Encoding','UTF-8');
base=z.cases(1); a=table(base.t,base.r,'VariableNames',{'时间_s','输入_V'});
for k=1:4, a.(sprintf('输出_方案%d_V',k))=interp1(z.cases(k).t,z.cases(k).y,base.t); end
writetable(a,fullfile(outDir,'阶跃波形数据.csv'),'Encoding','UTF-8');
p=z.square(1); a=table(p.t,p.r,p.y,interp1(z.square(2).t,z.square(2).y,p.t), ...
    'VariableNames',{'时间_s','输入_V','未校正输出_V','主方案输出_V'});
writetable(a,fullfile(outDir,'方波波形数据.csv'),'Encoding','UTF-8');
end

function writeSummary(z,outDir)
% 只写实际测得值，不抄指导书的示例曲线或近似结果。
fid=fopen(fullfile(outDir,'实验小结.md'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# 线性系统的串联校正实验\n\n');
fprintf(fid,'原被控对象 G(s)=20/[s(0.5s+1)]，采用单位负反馈。设计指标：超调量小于10%%、2%%调节时间不超过1s、速度误差系数Kv不小于20 s⁻¹。阶跃幅值1V，0.1s发生。信号源使用0.1ms一阶平滑以保证电容电路输入导数一致；传感器CH1记录平滑后的实际输入。表中时间从0.1s指令发生时刻起算。\n\n');
fprintf(fid,'## 电路与校正设计\n\n');
fprintf(fid,'A1：三只20kΩ电阻组成反相加法器，v1=−(r+v5)=y−r。A5：两只10kΩ电阻实现v5=−y。因此A1、A2与反馈构成正确的负反馈极性。\n\n');
fprintf(fid,'A2：输入阻抗为100kΩ与5µF并联，反馈阻抗为100kΩ与Cf并联，其传递函数为−(0.5s+1)/(100000Cf·s+1)。A1的反相符号与A2相消，得到正向校正Gc(s)。未校正电路省略A2的两只电容，保留单位反相放大。\n\n');
fprintf(fid,'A3：输入100kΩ，反馈500kΩ并联1µF，实现−5/(0.5s+1)。A4：输入250kΩ，反馈1µF，实现−4/s。两级串联正好等于题给G(s)，未改变原对象参数。所有运放同相端接地。\n\n');
fprintf(fid,'主方案Cf=0.25µF，Gc(s)=(0.5s+1)/(0.025s+1)，闭环W(s)=800/(s²+40s+800)，ζ=1/√2，ωn=√800 rad/s。故理论超调100exp(−π)=4.3214%%，理论峰值时间π/20=0.15708s，Kv=20 s⁻¹。\n\n');
fprintf(fid,'## 仿真测量\n\n|方案|Cf / µF|超调量 / %%|ts（2%%）/ s|ts（5%%）/ s|Kv / s⁻¹|\n|---|---:|---:|---:|---:|---:|\n');
for k=1:4
 q=z.cases(k);
 if k==1, cf='—'; else, cf=sprintf('%.2f',q.Cf*1e6); end
 fprintf(fid,'|%s|%s|%.4f|%.4f|%.4f|%.1f|\n',q.name,cf,q.metrics.Overshoot,q.metrics.SettlingTime,q.settling5percent,q.Kv);
end
fprintf(fid,'\n三组超前校正均满足设计要求，选Cf=0.25µF作为主方案，兼顾超调与速度。输出的速度误差系数是Kv；单位斜坡的稳态误差为1/Kv=0.05，不能把Kv本身写成稳态误差。\n\n');
fprintf(fid,'方波测量采用0~1V、周期10s、50%%占空比。未校正系统振荡明显；主方案在每次跳变后快速稳定。下降沿也会有对应的轻微负向过冲，不能截掉负半轴掩盖它。\n\n');
fprintf(fid,'## 复核与适用条件\n\n');
fprintf(fid,'两份SLX均为Simscape电阻、电容、理想运放、受控电压源与电压传感器的物理连接。Control System Toolbox的理论对照包含相同的信号源一阶平滑，仅用于独立对照，不替代电路求解。四组电路/理论最大偏差分别为');
for k=1:4, fprintf(fid,' %.3g V',z.cases(k).tfMaxError); end
fprintf(fid,'。主方案最大积分步长由1ms减半为0.5ms，输出最大差为%.3g V。\n\n',z.refinement.maxError);
fprintf(fid,'本实验仿真采用理想运放，不含供电限幅、有限增益带宽、转换速率和元件容差；属于MATLAB仿真测量，不是实物示波器测量。主方案校正级在1V理想阶跃瞬间约输出20V；若实物使用±15V运放，必须缩小输入幅值后重测，不能直接套用理想波形。用0.20µF时该瞬时值约25V。\n\n');
fprintf(fid,'设计利用校正零点与原对象0.5s极点相消，适用于本实验给定的标称参数；实物RC误差会影响相消效果，需按实际元件值重新仿真。指导书图中的12.5%%是示例，不能替代本设计测量。\n\n');
fprintf(fid,'## 重跑\n\n在MATLAB中打开本文件夹，运行 `run_experiment` 可重建模型、重算并重新出图；只重新绘图运行 `plot_experiment`；独立检查运行 `verify_experiment`。打开 `corrected_circuit.slx` 可直接运行主方案；Input_select上端为阶跃、下端为方波。\n');
end

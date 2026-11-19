function verify_experiment(rootDir)
% 复核电路级仿真数据、理论值、输出完整性和三项设计指标。
% 在 run_experiment 生成结果后可单独运行本函数；任何一项不符即报错。
if nargin==0, rootDir=fileparts(mfilename('fullpath')); end
f=fullfile(rootDir,'结果','仿真数据.mat');
assert(isfile(f),'ControlLab:NoResults','尚无电路仿真结果，不能宣布满足设计指标。');
s=load(f,'results'); z=s.results;
assert(numel(z.cases)==4,'原系统和三组校正方案必须齐全。');
for k=1:4
 q=z.cases(k);
 assert(all(isfinite(q.y)) && all(isfinite(q.internal(:))),'波形存在非有限值。');
 assert(q.tfMaxError<2e-4,'电路结果与闭环传递函数偏差过大。');
 assert(abs(q.y(end)-1)<0.002,'阶跃尚未充分稳定。');
 if k>1
  assert(q.metrics.Overshoot<10,'超调量未满足10%%以内。');
  assert(q.metrics.SettlingTime<=1,'2%%调节时间超过1s。');
  assert(q.Kv>=20-1e-9,'速度误差系数不足20。');
 end
end
assert(z.refinement.maxError<2e-4,'减半步长结果不一致。');
assert(abs(z.cases(3).metrics.Overshoot-100*exp(-pi))<0.02,'主方案超调量与二阶理论不符。');
need={'01_模拟电路图.png','02_原系统与校正方案阶跃对比.png','03_主方案阶跃测量.png','04_方波输入输出.png','05_校正网络与频率响应.png'};
for k=1:numel(need), assert(isfile(fullfile(rootDir,'结果',need{k})),['缺少图件：' need{k}]); end
assert(isfile(fullfile(rootDir,'original_circuit.slx')) && isfile(fullfile(rootDir,'corrected_circuit.slx')),'缺少可运行电路模型。');
fprintf('复核通过：4组电路仿真、理论对照、三项指标、步长敏感性、模型和图件均已检查。\n');
end

function plot_experiment(results,outDir)
% 从电路仿真数据绘制模拟电路图、阶跃测量、方波波形及校正网络图。
% 单独点击运行本文件会读取“结果/仿真数据.mat”，不会重新求解电路。
% 图中全部动态曲线来自Simscape电压传感器；虚线理论曲线单独标注。
rootDir=fileparts(mfilename('fullpath'));
if nargin<2, outDir=fullfile(rootDir,'结果'); end
if nargin<1
 z=load(fullfile(outDir,'仿真数据.mat'),'results'); results=z.results;
end
q=results.cases(3); t0=results.stepTime;
colors=[0.75 0.23 0.15; 0.10 0.55 0.37; 0.00 0.33 0.72; 0.58 0.24 0.65];
font='Microsoft YaHei';
% 一：与仿真模型逐级对应的完整模拟电路，清楚标出反馈极性与元件值。
f=makeFigure(1640,690); ax=axes(f,'Position',[0.025 0.05 0.95 0.91]);
axis(ax,[-0.5 32.5 -0.6 13.0]); axis(ax,'off'); hold(ax,'on');
text(ax,1,12.2,'1 V 阶跃，信号源平滑时间常数 0.1 ms；CH1 接输入，CH2 接输出', ...
    'FontSize',12,'FontWeight','bold','Color','k');
ampDraw(ax,5,7,'A1'); ampDraw(ax,12,7,'A2');
ampDraw(ax,19,7,'A3'); ampDraw(ax,26,7,'A4');
wire(ax,[0.8 2],[7.5 7.5]); node(ax,0.8,7.5);
resDraw(ax,2,3.4,7.5,'20 kΩ'); wire(ax,[3.4 5],[7.5 7.5]);
text(ax,0.75,8.2,'r(t) / CH1','FontSize',11,'Color','k');
feedbackR(ax,5,7,9.5,'20 kΩ');
% A1另外一路输入为v5=-y。
resDraw(ax,2,3.4,4.4,'20 kΩ'); wire(ax,[3.4 4.4 4.4],[4.4 4.4 7.5]); node(ax,4.4,7.5);
% A2输入阻抗：Ri并联Ci。输出阻抗：Rf并联Cf。
wire(ax,[6.6 8 8 9],[7 7 7.5 7.5]);
resDraw(ax,9,10.4,7.5,'Ri = 100 kΩ'); wire(ax,[10.4 12],[7.5 7.5]);
wire(ax,[8.7 8.7 9.3],[7.5 8.8 8.8]);
capDraw(ax,9.3,10.1,8.8,'Ci = 5 µF'); wire(ax,[10.1 11.5 11.5],[8.8 8.8 7.5]);
node(ax,8.7,7.5); node(ax,11.5,7.5);
feedbackR(ax,12,7,10.6,'Rf = 100 kΩ');
feedbackC(ax,12,7,9.4,'Cf = 0.25 µF');
% 原被控对象的惯性与积分电路。
wire(ax,[13.6 15 15 16],[7 7 7.5 7.5]);
resDraw(ax,16,17.4,7.5,'100 kΩ'); wire(ax,[17.4 19],[7.5 7.5]);
feedbackR(ax,19,7,10.2,'500 kΩ'); feedbackC(ax,19,7,8.9,'1 µF');
wire(ax,[20.6 22 22 23],[7 7 7.5 7.5]);
resDraw(ax,23,24.4,7.5,'250 kΩ'); wire(ax,[24.4 26],[7.5 7.5]);
feedbackC(ax,26,7,9.5,'1 µF');
wire(ax,[27.6 30.8],[7 7]); node(ax,30.8,7);
text(ax,30.8,7.8,'y(t) / CH2','FontSize',11,'Color','k','HorizontalAlignment','right');
% A5为向左输出的单位反相器，输出返回A1的第二只输入电阻。
patch(ax,[20 20 18.4],[1.3 3.3 2.3],'w','EdgeColor','k','LineWidth',1.3);
text(ax,19.65,2.8,'−','FontSize',12,'Color','k');
text(ax,19.65,1.8,'+','FontSize',12,'Color','k');
text(ax,19.3,2.35,'A5','FontSize',11,'Color','k','HorizontalAlignment','center');
wire(ax,[20 20.6 20.6],[1.8 1.8 1.1]); groundDraw(ax,20.6,1.1);
wire(ax,[29.6 29.6 24.4],[7 2.8 2.8]); node(ax,29.6,7);
resDraw(ax,23,24.4,2.8,'10 kΩ'); wire(ax,[23 20],[2.8 2.8]);
wire(ax,[20.6 20.6 20.3],[2.8 4.1 4.1]);
resDraw(ax,18.8,20.3,4.1,'10 kΩ'); wire(ax,[18.8 18 18 18.4],[4.1 4.1 2.3 2.3]);
wire(ax,[18.4 1.4 1.4 2],[2.3 2.3 4.4 4.4]);
text(ax,11.7,1.6,'v5 = −y(t)：单位负反馈','FontSize',11,'Color','k');
text(ax,4.8,11.5,'误差形成','FontSize',12,'FontWeight','bold','Color','k');
text(ax,11.8,11.5,'超前校正','FontSize',12,'FontWeight','bold','Color','k');
text(ax,18.6,11.5,'一阶惯性','FontSize',12,'FontWeight','bold','Color','k');
text(ax,25.8,11.5,'积分环节','FontSize',12,'FontWeight','bold','Color','k');
text(ax,1.0,0.15,'理想运放；全部同相输入端接地。A3、A4串联实现 G(s)=20/[s(0.5s+1)]。', ...
    'FontSize',11,'Color','k');
saveImage(f,'01_模拟电路图.png');
% 二：原系统与主方案，以及三组校正参数的直接比较。
f=makeFigure(1440,540); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl); hold(ax,'on');
a=results.cases(1); plot(ax,a.t-t0,a.y,'Color',colors(1,:),'LineWidth',1.4);
plot(ax,q.t-t0,q.y,'Color',colors(3,:),'LineWidth',1.8);
yline(ax,1,'k--','HandleVisibility','off');
xlim(ax,[0 5]); ylim(ax,[0 1.7]); xlabel(ax,'阶跃后时间 / s'); ylabel(ax,'输出电压 / V');
title(ax,'未校正与主方案'); legend(ax,{'未校正','主方案：Cf = 0.25 µF'},'Location','northeast'); style(ax);
ax=nexttile(tl); hold(ax,'on');
for k=2:4
 a=results.cases(k); plot(ax,a.t-t0,a.y,'Color',colors(k,:),'LineWidth',1.6);
end
yline(ax,1,'k:','HandleVisibility','off'); yline(ax,1.1,'k--','10% 上限', ...
    'LabelHorizontalAlignment','right','Color','k','HandleVisibility','off');
xlim(ax,[0 0.7]); ylim(ax,[0 1.16]); xlabel(ax,'阶跃后时间 / s'); ylabel(ax,'输出电压 / V');
title(ax,'三组校正参数对比');
legend(ax,{'Cf = 0.30 µF','Cf = 0.25 µF（主方案）','Cf = 0.20 µF'},'Location','southeast'); style(ax);
saveImage(f,'02_原系统与校正方案阶跃对比.png');
% 三：主方案的峰值、2%调节时间与内部节点；所有测量保留真实负向变化。
f=makeFigure(1440,560); tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl); hold(ax,'on');
patch(ax,[0 .6 .6 0],[.98 .98 1.02 1.02],[.90 .95 1], ...
    'FaceAlpha',0.7,'EdgeColor','none','HandleVisibility','off');
plot(ax,q.t-t0,q.y,'Color',colors(3,:),'LineWidth',1.9);
mask=q.t>=t0;
plot(ax,q.t(mask)-t0,q.theory(mask),'k--','LineWidth',0.8);
plot(ax,q.t-t0,q.r,'k:','LineWidth',1.1);
yline(ax,1,'k:','HandleVisibility','off');
plot(ax,q.metrics.PeakTime,q.metrics.Peak,'ko','MarkerFaceColor','w','HandleVisibility','off');
xline(ax,q.metrics.SettlingTime,'k-.','HandleVisibility','off');
text(ax,q.metrics.PeakTime+.015,q.metrics.Peak+.035, ...
    sprintf('峰值 %.4f V\n超调 %.3f%%',q.metrics.Peak,q.metrics.Overshoot), ...
    'FontSize',11,'Color','k');
text(ax,q.metrics.SettlingTime+.012,.35,sprintf('t_s（2%%）= %.4f s',q.metrics.SettlingTime), ...
    'FontSize',11,'Color','k');
xlim(ax,[-.025 .6]); ylim(ax,[0 1.2]); xlabel(ax,'阶跃后时间 / s'); ylabel(ax,'输出电压 / V');
title(ax,'主方案阶跃响应与指标测量');
legend(ax,{'电路输出 y(t)','含信号源平滑的理论','输入 r(t)'},'Location','southeast'); style(ax);
ax=nexttile(tl); hold(ax,'on');
plot(ax,q.t-t0,q.internal(:,2),'Color',colors(3,:),'LineWidth',1.6);
plot(ax,q.t-t0,q.internal(:,3),'Color',colors(1,:),'LineWidth',1.3);
plot(ax,q.t-t0,q.internal(:,1),'k--','LineWidth',1);
xlim(ax,[-.025 .5]); xlabel(ax,'阶跃后时间 / s'); ylabel(ax,'节点电压 / V');
title(ax,'内部节点电压（理想运放）');
legend(ax,{'A2：校正级输出','A3：惯性级输出','A1：y − r'},'Location','northeast'); style(ax);
saveImage(f,'03_主方案阶跃测量.png');
% 四：周期10s方波，对照未校正和主方案的完整波形。
f=makeFigure(1280,700); tl=tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
for k=1:2
 ax=nexttile(tl); hold(ax,'on'); a=results.square(k);
 plot(ax,a.t,a.r,'k--','LineWidth',1.0);
 if k==1, col=colors(1,:); name='未校正'; else, col=colors(3,:); name='主方案'; end
 plot(ax,a.t,a.y,'Color',col,'LineWidth',1.4);
 xlim(ax,[0 20]); ylim(ax,[-.7 1.7]); xticks(ax,0:2:20);
 xlabel(ax,'时间 / s'); ylabel(ax,'电压 / V'); title(ax,[name '：0～1 V 方波，周期 10 s']);
 legend(ax,{'输入 r(t)','输出 y(t)'},'Location','northeast'); style(ax);
end
saveImage(f,'04_方波输入输出.png');
% 五：校正网络单独元件图，及三组校正器的幅相曲线。
f=makeFigure(1450,640);
ax=axes(f,'Position',[.025 .12 .43 .78]); hold(ax,'on'); axis(ax,[0 13 0 11]); axis(ax,'off');
text(ax,.5,10.3,'可替换反馈电容的超前校正网络','FontSize',13,'FontWeight','bold','Color','k');
ampDraw(ax,7,4.5,'A2');
wire(ax,[.6 2],[5 5]); node(ax,.6,5);
resDraw(ax,2,3.6,5,'Ri = 100 kΩ'); wire(ax,[3.6 7],[5 5]);
wire(ax,[1.5 1.5 2.2],[5 6.7 6.7]); capDraw(ax,2.2,3.3,6.7,'Ci = 5 µF');
wire(ax,[3.3 6.5 6.5],[6.7 6.7 5]);
feedbackR(ax,7,4.5,8.5,'Rf = 100 kΩ'); feedbackC(ax,7,4.5,7.3,'Cf');
wire(ax,[8.6 11.6],[4.5 4.5]); node(ax,11.6,4.5);
text(ax,.4,4.4,'v1','FontSize',12,'Color','k'); text(ax,11.1,5.1,'v2','FontSize',12,'Color','k');
text(ax,.8,1.55,'v2/v1 = −(0.5s + 1)/(100000 Cf·s + 1)','FontSize',12,'Color','k');
text(ax,.8,.65,'Cf = 0.30 / 0.25 / 0.20 µF；主方案取 0.25 µF','FontSize',11,'Color','k');
w=logspace(-1,3,700);
ax1=axes(f,'Position',[.56 .59 .41 .32]); hold(ax1,'on');
ax2=axes(f,'Position',[.56 .14 .41 .32]); hold(ax2,'on');
for k=2:4
 h=squeeze(freqresp(results.cases(k).controller,w));
 semilogx(ax1,w,20*log10(abs(h)),'Color',colors(k,:),'LineWidth',1.4);
 semilogx(ax2,w,angle(h)*180/pi,'Color',colors(k,:),'LineWidth',1.4);
end
set([ax1 ax2],'XScale','log'); xlabel(ax1,'角频率 / (rad/s)'); ylabel(ax1,'Gc 幅值 / dB');
xlabel(ax2,'角频率 / (rad/s)'); ylabel(ax2,'Gc 相位 / (°)');
title(ax1,'校正器幅频特性'); title(ax2,'校正器相频特性');
legend(ax1,{'Cf = 0.30 µF','Cf = 0.25 µF','Cf = 0.20 µF'},'Location','northwest');
style(ax1); style(ax2);
saveImage(f,'05_校正网络与频率响应.png');

    function f=makeFigure(w,h)
        f=figure('Visible','off','Color','w','Position',[60 80 w h], ...
            'DefaultAxesFontName',font,'DefaultTextFontName',font, ...
            'DefaultAxesColor','w','DefaultAxesXColor','k','DefaultAxesYColor','k', ...
            'DefaultLegendColor','w','DefaultLegendEdgeColor','k', ...
            'DefaultTextColor','k','DefaultLegendTextColor','k');
    end
    function style(a)
        set(a,'FontName',font,'FontSize',11,'LineWidth',.8,'Box','on', ...
            'Color','w','XColor','k','YColor','k','TickDir','out','GridAlpha',.16);
        grid(a,'on'); a.Title.Color='k'; a.XLabel.Color='k'; a.YLabel.Color='k';
    end
    function saveImage(fig,name)
        exportgraphics(fig,fullfile(outDir,name),'Resolution',240,'BackgroundColor','white');
        close(fig);
    end
end

function wire(ax,x,y)
plot(ax,x,y,'k-','LineWidth',1.2,'HandleVisibility','off');
end
function node(ax,x,y)
plot(ax,x,y,'ko','MarkerSize',3,'MarkerFaceColor','k','HandleVisibility','off');
end
function resDraw(ax,x1,x2,y,label)
wire(ax,[x1 x1+.18],[y y]); wire(ax,[x2-.18 x2],[y y]);
rectangle(ax,'Position',[x1+.18 y-.13 x2-x1-.36 .26],'EdgeColor','k','LineWidth',1.2);
text(ax,(x1+x2)/2,y+.43,label,'HorizontalAlignment','center','FontSize',10.5,'Color','k','Interpreter','none');
end
function capDraw(ax,x1,x2,y,label)
x=(x1+x2)/2; wire(ax,[x1 x-.08],[y y]); wire(ax,[x+.08 x2],[y y]);
wire(ax,[x-.08 x-.08],[y-.30 y+.30]); wire(ax,[x+.08 x+.08],[y-.30 y+.30]);
text(ax,x,y+.48,label,'HorizontalAlignment','center','FontSize',10.5,'Color','k','Interpreter','none');
end
function groundDraw(ax,x,y)
wire(ax,[x x],[y y-.22]);
for k=0:2, w=.55-.15*k; wire(ax,[x-w/2 x+w/2],[y-.22-.12*k y-.22-.12*k]); end
end
function ampDraw(ax,x,y,name)
patch(ax,[x x x+1.6],[y-1 y+1 y],'w','EdgeColor','k','LineWidth',1.3);
text(ax,x+.10,y+.5,'−','FontSize',12,'Color','k');
text(ax,x+.10,y-.5,'+','FontSize',12,'Color','k');
text(ax,x+.63,y,name,'FontSize',11,'HorizontalAlignment','center','Color','k');
wire(ax,[x x-.22 x-.22 x+.65 x+.65],[y-.5 y-.5 y-1.35 y-1.35 y-1.6]);
groundDraw(ax,x+.65,y-1.6);
end
function feedbackR(ax,x,y,fy,label)
wire(ax,[x-.5 x-.5 x-.1],[y+.5 fy fy]);
resDraw(ax,x-.1,x+1.3,fy,label);
wire(ax,[x+1.3 x+2.2 x+2.2 x+1.6],[fy fy y y]);
node(ax,x-.5,y+.5); node(ax,x+2.2,y);
end
function feedbackC(ax,x,y,fy,label)
wire(ax,[x-.5 x-.5 x-.1],[y+.5 fy fy]);
capDraw(ax,x-.1,x+1.3,fy,label);
wire(ax,[x+1.3 x+2.2 x+2.2 x+1.6],[fy fy y y]);
node(ax,x-.5,y+.5); node(ax,x+2.2,y);
end

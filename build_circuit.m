function model=build_circuit(rootDir,isCorrected)
% 建立由实际Simscape电阻、电容和理想运放连接的模拟电路，并保存SLX。
% isCorrected=true：超前校正主方案；false：校正级仅作单位反相放大。
% 两个模型均可直接打开运行；无需个人路径或基础工作区参数。
if isCorrected, model='corrected_circuit'; else, model='original_circuit'; end
if bdIsLoaded(model), close_system(model,0); end
load_system('fl_lib'); load_system('nesl_utility');
modelPath=fullfile(rootDir,[model '.slx']);
if isfile(modelPath)
    load_system(modelPath); Simulink.BlockDiagram.deleteContents(model);
else
    new_system(model);
end
groundCount=0;
set_param(model,'Solver','ode23t','RelTol','1e-7','AbsTol','1e-9', ...
    'MaxStep','0.001','StopTime','6.1','ReturnWorkspaceOutputs','on', ...
    'OutputOption','SpecifiedOutputTimes','OutputTimes','0:0.0005:6.1', ...
    'SaveOutput','off','SaveTime','on','SignalLogging','off');
add_block('simulink/Sources/Step',[model '/Step_1V'], ...
    'Time','0.1','Before','0','After','1','Position',[30 150 65 185]);
add_block('simulink/Sources/Pulse Generator',[model '/Square_1V_10s'], ...
    'Amplitude','1','Period','10','PulseWidth','50','PhaseDelay','0.1', ...
    'Position',[30 220 65 255]);
add_block('simulink/Signal Routing/Manual Switch',[model '/Input_select'], ...
    'sw','1','Position',[110 155 140 225]);
add_line(model,'Step_1V/1','Input_select/1','autorouting','on');
add_line(model,'Square_1V_10s/1','Input_select/2','autorouting','on');
add_block('nesl_utility/Simulink-PS Converter',[model '/Input_V'], ...
    'Unit','V','FilteringAndDerivatives','filter','SimscapeFilterOrder','1', ...
    'InputFilterTimeConstant','1e-4','Position',[175 170 220 210]);
add_line(model,'Input_select/1','Input_V/1','autorouting','on');
vs=addElectrical('Electrical Sources/Controlled Voltage Source','Source',[225 330 265 390]);
pv=get_param([model '/Input_V'],'PortHandles'); connect(pv.RConn,vs.RConn(1));
ground(vs.RConn(2),[250 440]);
solver=addUtility('Solver Configuration','Physical_solver',[55 360 115 410]);
connect(solver.RConn,vs.RConn(2));
% A1：反相加法器，v1=-(r+v5)=y-r，三只电阻均为20kΩ。
a1=amp('A1_error',[435 340 495 420]);
r1=res('R1_input_20k',20e3,[315 380 365 400]);
rf1=res('R1_feedback_20k',20e3,[405 245 465 265]);
rb=res('R1_return_20k',20e3,[315 480 365 500]);
connect(vs.LConn,r1.LConn); connect(r1.RConn,a1.LConn(2));
connect(a1.LConn(2),rf1.LConn); connect(rf1.RConn,a1.RConn);
connect(rb.RConn,a1.LConn(2));
% A2：反相超前网络，-Zf/Zi；Ri=Rf=100kΩ，Ci=5µF，Cf=0.25µF。
a2=amp('A2_lead',[835 340 895 420]);
ri2=res('R2_input_100k',100e3,[650 380 710 400]);
rf2=res('R2_feedback_100k',100e3,[795 200 855 220]);
connect(a1.RConn,ri2.LConn); connect(ri2.RConn,a2.LConn(2));
connect(a2.LConn(2),rf2.LConn); connect(rf2.RConn,a2.RConn);
if isCorrected
 ci=cap('C2_input_5u',5e-6,[650 280 710 300]);
 cf=cap('C2_feedback',0.25e-6,[795 260 855 280]);
 connect(ri2.LConn,ci.LConn); connect(ci.RConn,ri2.RConn);
 connect(rf2.LConn,cf.LConn); connect(cf.RConn,rf2.RConn);
end
% A3：一阶惯性环节 -5/(0.5s+1)。
a3=amp('A3_lag',[1235 340 1295 420]);
ri3=res('R3_input_100k',100e3,[1060 380 1120 400]);
rf3=res('R3_feedback_500k',500e3,[1190 200 1250 220]);
c3=cap('C3_lag_1u',1e-6,[1190 260 1250 280]);
connect(a2.RConn,ri3.LConn); connect(ri3.RConn,a3.LConn(2));
connect(a3.LConn(2),rf3.LConn); connect(rf3.RConn,a3.RConn);
connect(rf3.LConn,c3.LConn); connect(c3.RConn,rf3.RConn);
% A4：积分环节 -4/s，和A3共同构成原被控对象G(s)。
a4=amp('A4_integrator',[1635 340 1695 420]);
ri4=res('R4_input_250k',250e3,[1460 380 1520 400]);
c4=cap('C4_integrator_1u',1e-6,[1590 260 1650 280]);
connect(a3.RConn,ri4.LConn); connect(ri4.RConn,a4.LConn(2));
connect(a4.LConn(2),c4.LConn); connect(c4.RConn,a4.RConn);
% A5：单位反相器，v5=-y；送回A1形成单位负反馈。
a5=amp('A5_return',[1035 740 1095 820]);
ri5=res('R5_input_10k',10e3,[860 780 920 800]);
rf5=res('R5_feedback_10k',10e3,[990 650 1050 670]);
connect(a4.RConn,ri5.LConn); connect(ri5.RConn,a5.LConn(2));
connect(a5.LConn(2),rf5.LConn); connect(rf5.RConn,a5.RConn);
connect(a5.RConn,rb.LConn);
% 电压传感器实际测量每一级输出，顺序为r,v1,v2,v3,y,v5。
add_block('simulink/Signal Routing/Mux',[model '/Measurements'], ...
    'Inputs','6','Position',[2040 430 2045 640]);
% 输入通道也使用电压传感器，记录实际信号源输出。
outs={vs.LConn,a1.RConn,a2.RConn,a3.RConn,a4.RConn,a5.RConn};
for k=1:6
 sensor=addElectrical('Electrical Sensors/Voltage Sensor', ...
     ['Sensor' num2str(k)],[1780 100+125*k 1810 145+125*k]);
 connect(outs{k},sensor.LConn); ground(sensor.RConn(2),[1780 180+125*k]);
 conv=addUtility('PS-Simulink Converter',['Voltage' num2str(k)], ...
     [1870 115+125*k 1920 145+125*k]);
 set_param([model '/Voltage' num2str(k)],'Unit','V');
 connect(sensor.RConn(1),conv.LConn);
 add_line(model,['Voltage' num2str(k) '/1'], ...
     ['Measurements/' num2str(k)],'autorouting','on');
end
add_block('simulink/Sinks/To Workspace',[model '/Measured_data'], ...
    'VariableName','measurements','SaveFormat','Timeseries', ...
    'Position',[2110 480 2210 515]);
add_block('simulink/Sinks/Scope',[model '/Input_and_node_voltages'], ...
    'Position',[2120 570 2170 620]);
add_line(model,'Measurements/1','Measured_data/1','autorouting','on');
add_line(model,'Measurements/1','Input_and_node_voltages/1','autorouting','on');
set_param(model,'ZoomFactor','75','Location',[50 70 1450 850]);
annotation=Simulink.Annotation(model, ...
    'r: 1 V step at 0.1 s | A1: error | A2: lead | A3+A4: plant | A5: -y | ideal op-amps');
annotation.Position=[400 80];
save_system(model,fullfile(rootDir,[model '.slx']));
    function ph=addElectrical(lib,name,pos)
        add_block(['fl_lib/Electrical/' lib],[model '/' name],'Position',pos);
        ph=get_param([model '/' name],'PortHandles');
    end
    function ph=addUtility(lib,name,pos)
        add_block(['nesl_utility/' lib],[model '/' name],'Position',pos);
        ph=get_param([model '/' name],'PortHandles');
    end
    function ph=res(name,value,pos)
        ph=addElectrical('Electrical Elements/Resistor',name,pos);
        set_param([model '/' name],'R',num2str(value,16),'R_unit','Ohm');
    end
    function ph=cap(name,value,pos)
        ph=addElectrical('Electrical Elements/Capacitor',name,pos);
        set_param([model '/' name],'c',num2str(value,16),'c_unit','F','r','0','g','0');
    end
    function ph=amp(name,pos)
        ph=addElectrical('Electrical Elements/Op-Amp',name,pos);
        ground(ph.LConn(1),[pos(1)-55 pos(2)-30]);
    end
    function ground(port,pos)
        groundCount=groundCount+1;
        g=addElectrical('Electrical Elements/Electrical Reference', ...
            ['GND_' num2str(groundCount)],[pos(1) pos(2) pos(1)+20 pos(2)+20]);
        connect(port,g.LConn);
    end
    function connect(p1,p2)
        add_line(model,p1,p2,'autorouting','on');
    end
end

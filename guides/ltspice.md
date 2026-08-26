---
name: LTspice
version: 26.0.2
icon: cpu
last_updated: 2026-08
min_version: 24
---

# LTspice 快捷键速查表

> 基于 LTspice 26.0.2 **默认配置**，兼容 24 / 26 版本。
>
> ⚠️ LTspice 支持自定义快捷键（菜单 **Help > Keyboard Shortcut Cheat Sheet > Edit Keyboard Shortcuts**），以下为出厂默认值。LTspice 自带始终置顶的快捷键速查表窗口，可通过 **Help > Keyboard Shortcut Cheat Sheet** 打开对照。

## 一、原理图编辑器 — 放置元件

| 快捷键 | 功能 |
|---|---|
| G | 接地（Ground） |
| V | 电压源（Voltage Source） |
| I | 电流源（Current Source） |
| R | 电阻（Resistor） |
| C | 电容（Capacitor） |
| L | 电感（Inductor） |
| D | 二极管（Diode） |
| P | 通用元件（Component，打开元件选择对话框） |
| N | 网络标签（Net Name，节点命名） |
| W | 画导线（Wire） |
| B | BUS 引出线（Bus Tap） |
| T | 注释文本（Comment Text） |
| . | SPICE 指令（SPICE Directive） |
| Alt+G | 放置 COM（公共端） |

> **重要**：`.` 放 SPICE 指令、`T` 放注释，两个键分开。`.options tnom=0` 这类指令必须用 `.` 键放置；用 T 放的就是注释，仿真时被忽略。
>
> **绘图提示**：用 Draw > Line/Rectangle/Circle/Arc 绘制图形注释时，按住 **Ctrl** 键可临时禁用网格吸附，实现自由定位。

---

## 二、原理图编辑器 — 编辑操作

> **三种编辑模式**：
> - **Expert Mode**（常用）：指向元件值等文本，光标变为 I 型时**右键**直接编辑
> - **Assisted Mode**：**右键元件体**，弹出 GUI 辅助编辑（适合不确定 SPICE 语法时）
> - **Super Expert Mode**：按住 **Ctrl + 右键元件体**，完全控制所有属性（可增删属性、设置可见性）

| 快捷键 | 功能 |
|---|---|
| Ctrl+R | 旋转元件（Rotate） |
| Ctrl+E | 镜像翻转（Mirror） |
| Ctrl+C | 复制模式（Duplicate） |
| Ctrl+V | 粘贴（Paste，复制后在目标窗口按此键） |
| Backspace | 删除模式（Delete） |
| M | 移动模式（Move） |
| S | 拖拽模式（Stretch / Drag） |
| Ctrl+Z | 撤销（Undo） |
| Ctrl+Shift+Z | 重做（Redo） |
| Esc | 退出当前模式（万能退出） |
| 右键 | 退出当前模式（Move/Stretch/Delete 等） |

---

## 三、原理图编辑器 — 仿真控制

| 快捷键 | 功能 |
|---|---|
| A | 配置仿真分析（.tran / .dc / .ac 等） |
| Alt+R | 运行 / 暂停仿真（Run / Pause） |
| Alt+S | 停止仿真（Stop） |
| Ctrl+H | 停止仿真（Halt Simulation） |
| Ctrl+L | 查看 SPICE 错误日志（验证指令是否生效） |

---

## 四、原理图编辑器 — 视图与缩放

| 快捷键 | 功能 |
|---|---|
| Space | 缩放适应窗口（Zoom to Fit） |
| Z | 区域放大（Zoom Area，拖拽框选） |
| Shift+Z | 缩放返回（Zoom Back） |
| Ctrl+- | 缩放返回（Zoom Back） |
| Ctrl+G | 网格显示切换（Grid Toggle） |
| 鼠标滚轮 | 缩放 |
| 中键拖拽 | 平移视图（Pan） |

---

## 五、符号编辑器（Symbol Editor）

> 用于编辑 .asy 符号文件。选中元件后按 Ctrl+E 可进入符号编辑。

| 快捷键 | 功能 |
|---|---|
| P | 放置引脚（Place Pin） |
| T | 放置注释文本（Comment Text） |
| O | 对象锚点切换（Object Anchors） |
| L | 画线（Draw Lines） |
| R | 画矩形（Draw Rectangles） |
| C | 画圆（Draw Circles） |
| A | 画弧线（Draw Arcs） |
| Ctrl+R | 旋转（Rotate） |
| Ctrl+E | 镜像（Mirror） |
| Ctrl+A | 属性编辑器（Attribute Editor） |
| Ctrl+W | 属性窗口（Attribute Window） |
| Ctrl+Z | 放大（Zoom In） |
| Ctrl+B | 缩放返回（Zoom Back） |
| Space | 缩放适应（Zoom to Fit） |

---

## 六、波形查看器（Waveform Viewer）

> 仿真运行后自动弹出的波形窗口。

| 快捷键 | 功能 |
|---|---|
| Ctrl+A | 添加轨迹（Add Trace） |
| Ctrl+E | 缩放适应（Zoom to Fit） |
| Ctrl+Z | 区域放大（Zoom Area） |
| Ctrl+B | 缩放返回（Zoom Back） |
| Ctrl+Y | 垂直自动量程（Vertical Autorange） |
| Ctrl+G | 网格切换（Toggle Grid） |
| Space | 重新加载绘图设置文件（Reload Plot Settings） |
| B | 在下方添加窗格（Add Pane Below） |
| U | 窗格上移（Move Pane Up） |
| D | 窗格下移（Move Pane Down） |
| C | 放置轨迹光标（Place Trace Cursor） |
| Shift+C | 清除所有光标（Clear All Cursors） |
| 方向键 | 移动附加光标（左/右移动，上/下在多组数据间切换） |
| L | 标注光标位置（Label Cursor Position） |
| T | 在图上放置文本（Place Text） |
| Ctrl+H | 停止仿真（Halt Simulation） |
| Ctrl+L | 查看 SPICE 日志 |

### 波形查看器鼠标操作

| 操作 | 功能 |
|---|---|
| 单击节点 | 绘制该节点电压波形 |
| 单击元件引脚 | 绘制该支路电流波形 |
| 单击元件体 | 绘制该元件电流波形 |
| Alt+单击元件 | 绘制瞬时功率（Power） |
| Alt+单击导线 | 绘制导线电流（Wire Current） |
| Ctrl+单击轨迹标签 | 查看该轨迹平均功率/平均值 |
| 双击同一节点/电流 | 单独显示该轨迹（清除其他所有轨迹） |
| 拖拽两个节点 | 绘制差分电压（Differential Voltage） |
| 右键波形标题 | 删除该轨迹 |
| 鼠标滚轮 | 缩放 |
| 中键拖拽 | 平移 |

---

## 七、网表编辑器（Netlist Editor）

> 编辑 .net 网表文件时使用。

| 快捷键 | 功能 |
|---|---|
| Ctrl+R | 运行仿真（Run Simulation） |
| Ctrl+H | 停止仿真（Halt Simulation） |
| Ctrl+G | 跳转到行号（Goto Line Number） |
| Ctrl+L | 查看 SPICE 错误日志 |

---

## 八、文本输入框（Edit Text）

> 在放置 SPICE 指令（.）或注释（T）时弹出的文本编辑框。

| 快捷键 | 功能 |
|---|---|
| Enter | 确定（= 点 OK）⚠️ 不是换行 |
| Shift+Enter | 换行（多行指令用这个） |
| Esc | 取消 |

---

## 九、SPICE 指令（Dot Commands）

> 用 `.` 键放置，以 `.` 开头才合法。按 `A` 键可快速配置仿真分析。

### 分析类指令

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .AC | 小信号交流分析（频响） | `.AC dec 100 1Hz 100MEG` |
| .DC | 直流源扫描分析 | `.DC V1 0 5 0.1` |
| .TRAN | 瞬态分析（时域） | `.TRAN 10u 1m` |
| .OP | 直流工作点分析 | `.OP` |
| .TF | 直流小信号传输函数 | `.TF V(out) V(in)` |
| .NOISE | 噪声分析 | `.NOISE V(out) V(in) dec 100 1Hz 100MEG` |
| .FOUR | 傅里叶分析（谐波） | `.FOUR 1k V(out)` |
| .FRA | 时域频响分析 | `.FRA V(out) V(in)` |
| .NET | 网络参数分析（配合 .AC） | `.NET V(out) I(Vin)` |

### 控制类指令

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .OPTIONS | 设置仿真器选项 | `.OPTIONS tnom=0 gmin=1e-9 itl4=100` |
| .PARAM | 自定义参数 | `.PARAM Rval=1k Cval=10n` |
| .STEP | 参数扫描 | `.STEP PARAM Rval 1k 10k 1k` |
| .TEMP | 温度扫描 | `.TEMP 0 27 50 100` |
| .IC | 设置初始条件 | `.IC V(out)=5V I(L1)=10mA` |
| .NODESET | 初始直流解提示（辅助收敛） | `.NODESET V(out)=0V` |
| .SAVE | 限制保存数据量 | `.SAVE V(out) I(R1)` |
| .MEASURE | 测量电气量 | `.MEAS TRAN t_rise TRIG V(out)=1 RISE=1 TARG V(out)=9 RISE=1` |
| .WAVE | 输出波形到 .wav 文件 | `.WAVE out.wav V(out)` |
| .END | 网表结束 | `.END` |
| .ENDS | 子电路定义结束 | `.ENDS` |

### 模型与子电路类

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .MODEL | 定义 SPICE 模型 | `.MODEL mymod D (Is=1n Rs=0.1)` |
| .SUBCKT | 定义子电路 | `.SUBCKT myamp in out VCC` |
| .INCLUDE | 包含其他网表文件 | `.INCLUDE models.lib` |
| .LIB | 包含模型库 | `.LIB opamp.lib OP07` |
| .GLOBAL | 声明全局节点 | `.GLOBAL GND VCC` |
| .FUNC | 用户自定义函数 | `.FUNC myfunc(x) {x*x+1}` |
| .MACHINE | 任意状态机 | `.MACHINE sm1 clk reset state0 state1` |
| .BACKANNO | 子电路引脚名标注 | `.BACKANNO` |
| .KEEPNODE | 防止节点被优化掉 | `.KEEPNODE V(out)` |

### 工作点存取类

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .SAVEBIAS | 保存直流工作点到磁盘 | `.SAVEBIAS bias.txt` |
| .LOADBIAS | 加载之前的直流工作点 | `.LOADBIAS bias.txt` |
| .SAVESTATE | 保存瞬态工作点 | `.SAVESTATE state.txt` |
| .LOADSTATE | 加载瞬态工作点 | `.LOADSTATE state.txt` |

### .OPTIONS 常用参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| tnom | 27℃ | 元件参数标定温度 |
| temp | 27℃ | 仿真环境温度 |
| gmin | 1e-12 | PN 结辅助收敛电导 |
| itl1 | 100 | 直流迭代次数上限 |
| itl4 | 10 | 瞬态时间点迭代上限 |
| abstol | 1pA | 电流绝对误差容限 |
| vntol | 1uV | 电压绝对误差容限 |
| chgtol | 10fC | 电荷绝对误差容限 |
| reltol | 0.001 | 相对误差容限 |
| method | trap | 积分方法（trap/gear） |
| uic | false | 跳过初始直流工作点计算 |

### 指令详细说明

#### .TRAN — 瞬态分析

最常用的仿真类型，计算电路上电后随时间的变化。

语法：.TRAN <Tstep> <Tstop> [Tstart [dTmax]] [modifiers]

参数说明：Tstep 是波形绘图增量（LTspice 用波形压缩，此参数意义不大），Tstop 是仿真停止时间，Tstart 是开始保存数据的时间，dTmax 是最大时间步长。加 UIC 跳过初始直流工作点计算，使用 .IC 设置的初始条件。

示例：.TRAN 1u 1m （仿真 1ms，每 1us 绘图）

#### .AC — 小信号交流分析

计算电路在直流工作点附近的线性频响。

语法：.AC <oct|dec|lin> <npoints> <fstart> <fstop>

参数说明：oct 每倍频程点数，dec 每十倍频程点数，lin 线性点数。

示例：.AC dec 100 1Hz 100MEG （从 1Hz 到 100MHz，每十倍频 100 个点）

用途：滤波器、稳定性分析、噪声分析。

#### .DC — 直流源扫描分析

扫描直流源的值，计算直流传输特性。

语法：.DC <sweep1> [<sweep2> [<sweep3>]]

每个 sweep 格式：[<oct|dec|lin>] <srcnam> <start> <stop> <incr>。srcnam 是独立电压/电流源名。可嵌套最多 3 层扫描。

示例：.DC V1 0 5 0.1 （扫描 V1 从 0 到 5V，步长 0.1V）

#### .OP — 直流工作点分析

计算电路的直流工作点（所有节点电压、元件电流/功耗）。

语法：.OP （无参数）

仿真结果在日志文件中查看（Ctrl+L）。是 .AC/.TRAN 等分析的基础（先算 .OP 再线性化）。

#### .NOISE — 噪声分析

计算电路的噪声频谱。

语法：.NOISE V(out) <src> <sweep>

参数说明：V(out) 是输出节点，src 是等效输入噪声参考源，sweep 格式同 .AC。

示例：.NOISE V(out) V1 dec 100 1Hz 100MEG

输出包括热噪声、散粒噪声、闪烁噪声。

#### .TF — 直流小信号传输函数

计算直流小信号传输函数、输入电阻、输出电阻。

语法：.TF <outvar> <src>

参数说明：outvar 是输出变量（如 V(out)），src 是输入源。

示例：.TF V(out) V1

结果在日志中查看，包括增益、Rin、Rout。

#### .FOUR — 傅里叶分析

计算瞬态分析结果的傅里叶级数分量。

语法：.FOUR <freq> <v1> [<v2> ...]

参数说明：freq 是基频，v1/v2 是要分析的输出变量。

示例：.FOUR 1k V(out)

需要配合 .TRAN 使用，仿真时间应至少包含几个周期。结果在日志中查看。

#### .OPTIONS — 设置仿真器选项

设置仿真器的各种参数。

语法：.OPTIONS <param1>=<val1> <param2>=<val2> ...

常用参数：
tnom：标定温度，默认27
temp：仿真温度，默认27
gmin：辅助收敛电导，默认1e-12
itl1：直流迭代上限，默认100
itl4：瞬态迭代上限，默认10
abstol：电流容限，默认1pA
reltol：相对容限，默认0.001
method：积分方法 trap/gear
uic：跳过初始工作点

示例：.OPTIONS tnom=0 gmin=1e-9 itl4=100

#### .PARAM — 自定义参数

定义用户常量，用于参数化电路。

语法：.PARAM <name>=<value> [<name2>=<value2> ...]

可在元件值中用 {name} 引用。可放在子电路内限制作用域。24.1+ 版本大部分情况不需要花括号。

示例：.PARAM Rval=1k Cval=10n （电阻值设为 {Rval}）

#### .STEP — 参数扫描

重复执行分析，每次改变参数值。

语法：.STEP [<oct|dec|lin>] <item> <start> <end> <incr>

参数说明：item 可以是温度、模型参数、全局参数、独立源。可嵌套最多 3 层。

示例：.STEP PARAM Rval 1k 10k 1k （扫描 Rval 从 1k 到 10k）

波形查看器中显示多条曲线。

#### .TEMP — 温度扫描

设置仿真温度（等效于 .STEP temp）。

语法：.TEMP <t1> [<t2> ...]

示例：.TEMP 0 27 50 100 （在 4 个温度下分别仿真）

温度影响元件模型参数（如电阻温度系数、PN 结 Is）。

#### .IC — 设置初始条件

设置节点电压/电感电流的初始值。

语法：.IC V(<node>)=<value> [I(<inductor>)=<value>]

示例：.IC V(out)=5V I(L1)=10mA

需配合 .TRAN ... UIC 才会真正作为起点，否则先算直流工作点会覆盖。

#### .MEASURE — 测量电气量

在仿真结果中测量用户定义的电气量。

语法：.MEAS[URE] [AC|DC|OP|TRAN|TF|NOISE] <name> <FIND|DERIV|PARAM> <expr> [WHEN <expr>|AT=<expr>]

示例：.MEAS TRAN t_rise TRIG V(out)=1 RISE=1 TARG V(out)=9 RISE=1 （测量上升时间）

结果在日志中查看。

#### .MODEL — 定义 SPICE 模型

定义二极管、晶体管、开关等元件的模型参数。

语法：.MODEL <modname> <type>[(<param list>)]

type 包括：D（二极管）、NPN/PNP（BJT）、NMOS/PMOS（MOS）、SW/CSW（开关）等。

示例：.MODEL mydiode D (Is=1n Rs=0.1 N=1.5)

同型号元件共享模型参数，实例可指定尺寸缩放。

#### .SUBCKT — 定义子电路

定义可复用的子电路模块。

语法：.SUBCKT <name> <node1> [<node2> ...]，以 .ENDS <name> 结束。

子电路可包含元件、参数、模型，用 X<name> <nodes> <subcktname> 调用。可参数化，用 .PARAM 传递参数。

示例：.SUBCKT myamp in out VCC ... .ENDS myamp

#### .INCLUDE — 包含其他文件

包含另一个网表/模型文件。

语法：.INCLUDE <filename>

示例：.INCLUDE models.lib

文件内容会被插入到当前位置。路径相对于当前原理图文件目录。常用于共享模型库。

#### .LIB — 包含模型库

包含库文件中的特定模型。

语法：.LIB <filename> [<modelname>]

示例：.LIB opamp.lib OP07

库文件中包含多个 .MODEL/.SUBCKT 定义，用 modelname 选择。LTspice 自带大量元件库在 lib/cmp/ 目录。

#### .SAVE — 限制保存数据量

只保存指定的节点电压/元件电流，减少波形文件大小。

语法：.SAVE <v1> [<v2> ...]

示例：.SAVE V(out) I(R1) V(in)

默认保存所有节点，大电路仿真时可显著减小 .raw 文件。

#### .NODESET — 初始直流解提示

为直流工作点计算提供初始猜测，辅助收敛。

语法：.NODESET V(<node>)=<value>

示例：.NODESET V(out)=0V

与 .IC 不同：.NODESET 只是猜测，迭代后会修正；.IC 配合 UIC 是强制初始值。

#### .FUNC — 用户自定义函数

定义可在表达式中使用的函数。

语法：.FUNC <name>(<args>) {<expression>}

示例：.FUNC myfunc(x) {x*x+1}

可在 .PARAM、元件值、行为源中调用。支持多参数，表达式可用标准 SPICE 函数（sin/cos/exp/log 等）。

### 命令行开关（Command Line Switches）

> 通过命令行启动 LTspice 时可附加参数，适用于批处理、自动化仿真、CI 集成等场景。
> macOS 下通过 `open -a LTspice --args <参数>` 或直接调用可执行文件使用。

| 参数 | 功能 |
|---|---|
| `-b` | 批处理模式运行（如 `ltspice -b deck.cir`，仿真后数据存入 deck.raw，不打开 GUI） |
| `-netlist` | 批量将原理图（.asc）转换为 SPICE 网表（.net） |
| `-PCBnetlist` | 批量将原理图转换为 PCB 格式网表 |
| `-Run` | 打开命令行指定的原理图后**自动开始仿真**，无需手动点 Run |
| `-big` / `-max` | 以最大化窗口启动 |
| `-alt` | 设置求解器为 Alternate 模式（可被网表中的 .OPTIONS 覆盖） |
| `-norm` | 设置求解器为 Normal 模式（可被网表中的 .OPTIONS 覆盖） |
| `-ascii` | 使用 ASCII 格式 .raw 文件（人类可读，但严重降低性能和增大文件） |
| `-FastAccess` | 批量将二进制 .raw 文件转换为 Fast Access 格式（加速大数据波形浏览） |
| `-ini <path>` | 指定使用的 .ini 配置文件路径（替代默认 %APPDATA%/LTspice.ini） |
| `-I<path>` | 添加符号/文件搜索路径（必须是最后一个参数，`-I` 和路径间**无空格**） |
| `-encrypt` | 加密模型库（第三方库保护，用户可使用但看不到实现细节） |
| `-FixUpSchematicFonts` | 转换旧版原理图文本字体大小字段为现代默认值 |
| `-FixUpSymbolFonts` | 转换旧版符号字体大小字段为现代默认值 |

**常用示例**：
```bash
# 批处理仿真（不打开 GUI）
ltspice -b mycircuit.asc

# 打开原理图并自动开始仿真
ltspice -Run mycircuit.asc

# 原理图转网表
ltspice -netlist mycircuit.asc
```

---

## ⚠️ 特别注意事项

1. **`.` 键 vs `T` 键**：`.options tnom=0` 这类指令必须用 `.` 键放置；用 T 放的就是注释，仿真时被忽略。

2. **SPICE 指令以 `.` 开头**才合法；注释、空行、`*` 开头行都不会执行。

3. **验证指令是否生效**：跑完仿真 → **Ctrl+L** 看日志。如 `.options tnom=0` 生效，日志会显示 `tnom = 0`（默认 27）。

4. **`.asc` 与 `.net` 是单向转换**：原理图 → 自动生成网表；手写的 .net 内容不会回写原理图，重新生成会**覆盖丢失**。

5. **电流源（I/G 源）输出端必须接负载电阻**到地，否则报 `floating` 错误——电流源不决定节点电压，电压才由负载决定。

6. **受控源字母记忆**：E、G 是**电压控制**（VCVS/VCCS），F、H 是**电流控制**（CCCS/CCVS）；增益是乘法，H 源增益乘的是**电流**（V = 增益 × I）。

7. **`temp` vs `tnom`**：`temp` 是仿真环境温度，`tnom` 是元件参数标定温度（默认 27℃）。想改基准用 `.options tnom=...`。

8. **电容 `ic=1V`（初始条件）**：只在瞬态分析生效，且要配合 `.tran ... UIC` 才会真正作为起点，否则先算直流工作点会覆盖它。

9. **Ctrl+L 的日志文件**同时保存在网表同目录的 `.log` 文件中，可直接用文本编辑器查看。

10. **快捷键仅在英文输入法下生效**：中文输入法下字母键会被输入法拦截，所有单字母快捷键（G/R/C/W/M/S/A 等）均不起作用。使用前请切换到英文输入法（按 `Caps Lock` 或 `⌘+空格` 切换）。

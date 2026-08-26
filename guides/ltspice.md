---
name: LTspice
version: 26.0.2
icon: cpu
last_updated: 2026-08
min_version: 24
---

# LTspice 快捷键速查表（Mac 版）

> 基于 LTspice 26 官方快捷键速查表，**Mac 版默认配置**。
>
> ⚠️ LTspice 支持自定义快捷键（菜单 **Help > Keyboard Shortcut Cheat Sheet > Edit Keyboard Shortcuts**），以下为出厂默认值。LTspice 自带始终置顶的快捷键速查表窗口，可通过 **Help > Keyboard Shortcut Cheat Sheet** 打开对照。
>
> ⚠️ 所有快捷键仅在**英文输入法**下生效，中文输入法下字母键会被拦截。

## 一、放置元件（Place Components）

| 快捷键 | 功能 |
|---|---|
| W | 画导线（Wire） |
| G | 接地（Ground） |
| ⌥G | 放置 COM（公共端） |
| V | 电压源（Voltage Source） |
| R | 电阻（Resistor） |
| C | 电容（Capacitor） |
| L | 电感（Inductor） |
| D | 二极管（Diode） |
| P | 通用元件（Component，打开元件选择对话框） |
| N | 网络标签（Label Net，节点命名） |
| T | 注释文本（Text/Comment） |
| . | SPICE 指令（SPICE Directive） |
| B | BUS 引出线（Bus Tap） |
| ⌥+左键 | 切换指令/注释（toggle directive/comment） |

> **重要**：`.` 放 SPICE 指令、`T` 放注释，两个键分开。`.options tnom=0` 这类指令必须用 `.` 键放置；用 T 放的就是注释，仿真时被忽略。
>
> **按 `Esc` 或右键退出放置模式。**

---

## 二、通用编辑（General Editing）

> **verb-noun 操作模式**：LTspice 是"先动词后名词"的接口——先选择操作（旋转/镜像/移动/删除等），再点击对象。例如要旋转元件，先按 `⌘R`，再点击元件；要删除，先按 `⌘X`，再点击元件。可拖拽框选多个对象。按 `Esc` 或右键退出当前模式。

| 快捷键 | 功能 |
|---|---|
| ⌘X 或 , 或 Backspace | 删除模式（Delete） |
| ⌘C | 复制模式（Duplicate） |
| M | 移动模式（Move，选择要移动的元件） |
| S | 拉伸模式（Stretch，选择锚点移动） |
| ⌘R | 旋转（Rotate） |
| ⌘E | 镜像（Mirror） |
| Z | 区域放大（拖拽框选）/ 点击放大 |
| ⇧Z | 缩小（Zoom Out） |
| Space | 缩放适应窗口（Zoom to Fit / Zoom Extents） |
| ⌘G | 网格显示切换（Toggle Grid） |
| ⌘Z | 撤销（Undo） |
| ⌘⇧Z | 重做（Redo） |

> **Duplicate（复制）操作流程**：按 `⌘C` 进入复制模式 → 点击要复制的元件（副本跟随鼠标）→ 移动到目标位置点击左键放置 → 可连续点击放置多个副本 → 右键或 `Esc` 退出。**同一窗口内不需要 `⌘V` 粘贴**。
>
> **放置时旋转/镜像**：在放置元件的过程中（元件还跟随鼠标时），按 `⌘R` 旋转、`⌘E` 镜像，放下去就是转好的方向，不用放完再改。

---

## 三、原理图选项（Schematic Options）

> 这些是按住修饰键或组合键触发的临时选项，大部分也可在 Settings 中永久设置。

| 操作 | 功能 |
|---|---|
| 按住 ⌘ 画导线 | 允许画任意角度导线（place angled wires，临时切换正交吸附） |
| 按住 ⌘ 画图形 | 图形离格绘制（draw shapes off grid，临时禁用网格吸附） |
| ⌘⌥⇧H | 显示隐藏文本（rser=1 等，如并联/串联电阻） |
| ⌘U | 显示/隐藏未连接引脚标记（UN） |
| ⌘A | 显示/隐藏文本锚点标记（V1） |

---

## 四、探针操作（Probe Schematic）

> 仿真运行后，直接在原理图上点击即可探测波形。

| 操作 | 功能 |
|---|---|
| 单击导线 | 绘制该节点电压波形 |
| 单击元件体 | 绘制该元件电流波形 |
| 单击元件引脚 | 绘制该引脚电流波形 |
| ⌥+单击导线 | 绘制导线电流（Wire Current） |
| ⌥+单击元件 | 绘制瞬时功率（Instantaneous Power） |
| 拖拽两个节点 | 绘制差分电压（Differential Voltage） |
| 双击同一节点/电流 | 单独显示该轨迹（清除其他所有轨迹） |

> **探针仅在仿真运行后可用。**

---

## 五、仿真控制（Simulator）

| 快捷键 | 功能 |
|---|---|
| A | 配置仿真分析（Configure Analysis） |
| ⌥R | 运行/暂停仿真（Run / Pause） |
| ⌥S | 停止仿真（Stop） |
| ⌘L | 查看 SPICE 错误日志（验证指令是否生效） |
| 0 | 重置仿真波形 T=0 |

> 仿真运行时仍可编辑原理图，编辑会影响后续仿真。

---

## 六、波形查看（Waveform Viewing）

> 仿真运行后自动弹出的波形窗口。鼠标操作针对轨迹标签（trace label）。

| 快捷键 / 操作 | 功能 |
|---|---|
| 单击轨迹 或 C | 添加光标并查看测量值（add cursor and see measure） |
| L | 标注当前光标位置（Label Cursor Position） |
| ⌘C 或 Esc | 清除所有光标（Clear All Cursors） |
| ⌘+单击轨迹标签 | 在原理图中高亮对应网络 |
| ⌥+单击轨迹标签 | 积分（Integrate） |
| 拖拽轨迹标签 | 移动轨迹到其他窗格 |
| 拖拽时按住 ⌘ | 复制轨迹到其他窗格 |
| A | 添加轨迹（Add Trace） |
| P | 上方添加窗格（Add Pane Above） |
| B | 下方添加窗格（Add Pane Below） |
| U | 活动窗格上移（Move Active Pane Up） |
| D | 活动窗格下移（Move Active Pane Down） |
| ⇧S | 选择 Step（Select Steps） |
| 鼠标滚轮 | 缩放 |
| 中键拖拽 | 平移 |

---

## 七、波形平移与光标（Waveform Pan & Cursor）

> 在波形窗格内点击以激活键盘操作。

| 操作 | 无光标时 | 有光标时 |
|---|---|---|
| 方向键（←→↑↓） | 平移 ~25% | 光标吸附到下一个时间数据点 |
| ⇧+方向键 | 平移 ~50% | 光标吸附到下一个数据点 |
| ⌥+方向键 或 ⌘+方向键 | — | 光标跳 10 个数据点 |
| ⌘⌥+方向键 | — | 光标跳 100 个数据点 |
| 按住 ⌘ + 鼠标拖拽 | 平移视图 | — |
| 按住 ⌘⌥ + 鼠标左右拖拽 | 左右平移 | — |
| 按住 ⌥⌘ + 鼠标上下拖拽 | 上下平移 | — |

> 有光标时，↑↓ 键可在多组数据（.step/.dc/.temp）间切换光标所属轨迹。

---

## 八、符号编辑器绘图（Drawing）

> 用于编辑 .asy 符号文件。选中元件后按 `⌘E`（Mirror）或通过菜单进入符号编辑。
>
> ⚠️ 符号编辑器与原理图编辑器共享部分单字母快捷键（如 L=电感、R=电阻等），绘图工具建议通过菜单 **Draw >** 访问，避免冲突。

| 菜单操作 | 功能 |
|---|---|
| Draw > Text | 放置文本（T） |
| Draw > Line | 画线 |
| Draw > Rectangle | 画矩形 |
| Draw > Ellipse | 画椭圆/圆 |
| Draw > Arc | 画弧线 |
| Edit > Add Pin/Port | 添加引脚 |
| Edit > Attributes > Edit Attributes | 编辑属性（⌘A） |
| Edit > Attributes > Attribute Window | 属性窗口（⌘W） |

> 符号编辑器中 `⌘R` 旋转、`⌘E` 镜像、Space 缩放适应等通用编辑快捷键同样适用。

---

## 九、网表编辑器（Netlist Editor）

> 编辑 .net 网表文件时使用。

| 快捷键 | 功能 |
|---|---|
| ⌘R | 运行仿真（Run Simulation） |
| ⌘H | 停止仿真（Halt Simulation） |
| ⌘G | 跳转到行号（Goto Line Number） |
| ⌘L | 查看 SPICE 错误日志 |

---

## 十、文本输入框（Edit Text）

> 在放置 SPICE 指令（.）或注释（T）时弹出的文本编辑框。

| 快捷键 | 功能 |
|---|---|
| Enter | 确定（= 点 OK）⚠️ 不是换行 |
| ⇧Enter | 换行（多行指令用这个） |
| Esc | 取消 |

---

## 十一、SPICE 分析指令（SPICE Analysis）

> 用 `.` 键放置，以 `.` 开头才合法。按 `A` 键可快速配置仿真分析。**仿真需要且仅需要一个激活的分析指令**。

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .AC | 小信号交流分析（频响） | `.AC <oct,dec,lin> <Npoints> <startfreq> <endfreq>` |
| .DC | 直流源扫描分析 | `.DC <sourcename> <oct,dec,lin> <start> <stop> <incr> [more sources]` |
| .TRAN | 瞬态分析（时域） | `.TRAN <Tstep> <Tstop> [Tstart [dTmax]] [uic] [steady] [nodiscard] [startup] [step] [loadstate=] [savestate=] [savestatetime=]` |
| .OP | 直流工作点分析 | `.OP` |
| .TF | 直流小信号传输函数 | `.TF V(<node>[,<refnode>]) <source>` 或 `.TF I(<Vsource>) <source>` |
| .NOISE | 噪声分析 | `.NOISE V(<node>[,<refnode>]) <src> <oct,dec,lin> <Npoints> <startfreq> <endfreq>` |
| .FOUR | 傅里叶分析（谐波） | `.FOUR <freq> [Nharmonics] [Nperiods] <datatrace> [...]` |
| .FRA | 时域频响分析 | `.FRA [Tstart=<time>] [dTmax=<time>] [Tstep=<time>] [Tstop=<time>] [uic] [startup]` |
| .NET | 网络参数分析（配合 .AC） | `.NET [V(out[,ref]),I(Rout)] <Vin,Iin> [Rin=<val>] [Rout=<val>]` |

### .TRAN — 瞬态分析（最常用）

语法：`.TRAN <Tstep> <Tstop> [Tstart [dTmax]] [modifiers]`

- **Tstep**：波形绘图增量（LTspice 用波形压缩，此参数意义不大，可设 0）
- **Tstop**：仿真停止时间
- **Tstart**：开始保存数据的时间（之前的数据不保存，用于忽略启动瞬态）
- **dTmax**：最大时间步长
- **uic**：跳过初始直流工作点计算，使用 .IC 设置的初始条件（⚠️ 不推荐作为收敛问题的变通方案）
- **steady**：稳态检测
- **nodiscard**：不丢弃数据
- **startup**：启动瞬态
- **loadstate/savestate**：加载/保存瞬态状态文件（24.1+）

示例：`.TRAN 1u 1m`（仿真 1ms，每 1us 绘图）

### .AC — 小信号交流分析

语法：`.AC <oct,dec,lin> <Npoints> <StartFreq> <EndFreq>`

- **oct**：每倍频程点数
- **dec**：每十倍频程点数
- **lin**：线性总点数

另支持 `.AC list <freq> [...]`（指定频率列表）和 `.AC file=<filename>`（从文件读取频率）。

示例：`.AC dec 100 1Hz 100MEG`（从 1Hz 到 100MHz，每十倍频 100 点）

用途：滤波器、稳定性分析、噪声分析。

### .DC — 直流源扫描分析

语法：`.DC <sourcename> <oct,dec,lin> <startvalue> <stopvalue> <incr> [more sources]`

可嵌套最多 3 层扫描。另支持 list 和 file= 形式。

示例：`.DC V1 0 5 0.1`（扫描 V1 从 0 到 5V，步长 0.1V）

### .OP — 直流工作点分析

计算直流工作点（所有节点电压、元件电流/功耗）。结果会弹出对话框，也可在日志（⌘L）中查看。是 .AC/.TRAN 等分析的基础。

### .NOISE — 噪声分析

计算热噪声、散粒噪声、闪烁噪声的频谱密度。输出包括 V(onoise)（输出噪声）、V(inoise)（输入参考噪声）。

示例：`.NOISE V(out) V1 dec 100 1Hz 100MEG`

### .TF — 直流小信号传输函数

计算直流小信号增益、输入电阻、输出电阻。结果在日志中查看。

示例：`.TF V(out) V1`

### .FOUR — 傅里叶分析

在瞬态分析后计算傅里叶级数分量。默认 9 次谐波。结果在日志中查看。Nperiods=-1 表示使用整个仿真数据范围。

示例：`.FOUR 1k V(out)`

---

## 十二、SPICE 控制指令（SPICE Directives）

### 控制类

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .OPTIONS | 设置仿真器选项 | `.OPTIONS tnom=0 gmin=1e-9 itl4=100` |
| .PARAM | 自定义参数 | `.PARAM Rval=1k Cval=10n` |
| .STEP | 参数扫描 | `.STEP PARAM Rval 1k 10k 1k` |
| .TEMP | 温度扫描（同 .STEP temp list） | `.TEMP 0 27 50 100` |
| .IC | 设置初始条件 | `.IC V(out)=5V I(L1)=10mA` |
| .NODESET | 初始直流解提示（辅助收敛） | `.NODESET V(out)=0V` |
| .SAVE | 限制保存数据量 | `.SAVE V(out) I(R1)` |
| .MEASURE | 测量电气量 | `.MEAS TRAN t_rise TRIG V(out)=1 RISE=1 TARG V(out)=9 RISE=1` |
| .WAVE | 输出波形到 .wav 文件 | `.WAVE out.wav 16 44.1K V(left) V(right)` |
| .END | 网表结束（网表生成器自动添加，勿手动放在原理图上） | `.END` |
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
| .MACHINE | 任意状态机 | `.MACHINE ... .ENDMACHINE` |
| .BACKANNO | 子电路引脚名标注（网表生成器自动添加） | `.BACKANNO` |
| .KEEPNODE | 防止节点被优化掉（主要用于 .NOISE） | `.KEEPNODE V(out)` |

### 工作点存取类

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .SAVEBIAS* | 保存直流工作点到磁盘 | `.SAVEBIAS bias.txt [internal]` |
| .LOADBIAS* | 加载之前的直流工作点 | `.LOADBIAS bias.txt` |
| .SAVESTATE** | 保存瞬态工作点（专有格式） | `.SAVESTATE state.txt [time=<time>]` |
| .LOADSTATE** | 加载瞬态工作点 | `.LOADSTATE state.txt [reset]` |

> \* .SAVEBIAS/.LOADBIAS 已被 .SAVESTATE/.LOADSTATE 取代
> \*\* .SAVESTATE/.LOADSTATE 为 24.1 及以后版本功能

### .OPTIONS 常用参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| abstol | 1pA | 电流绝对误差容限 |
| chgtol | 10fC | 电荷绝对误差容限 |
| cshunt | 0 | 每个节点到地的附加电容 |
| gmin | 1e-12 | PN 结辅助收敛电导 |
| gminsteps | 25 | 初始直流解的 gmin 步进次数（0=禁用） |
| itl1 | 100 | 直流迭代次数上限 |
| itl2 | 50 | 直流传输曲线迭代次数上限 |
| itl4 | 10 | 瞬态时间点迭代次数上限 |
| itl6/srcsteps | 25 | 初始直流解的源步进次数（0=禁用） |
| maxstep | ∞ | 瞬态分析最大步长 |
| method | trap | 积分方法（trap/modtrap/gear） |
| pivrel | 0.001 | 主元相对比率 |
| pivtol | 1e-13 | 主元绝对值下限 |
| reltol | 0.001 | 相对误差容限 |
| temp | 27℃ | 电路元件默认温度 |
| tnom | 27℃ | 模型参数标定温度 |
| uic | false | 跳过初始直流工作点计算 |
| vntol | 1μV | 电压绝对误差容限 |
| solver | (none) | 求解器（norm/alt），覆盖命令行 -alt/-norm |
| topologycheck | 1 | 拓扑检查（0=跳过浮动节点/电压源回路/变压器检查） |

### 指令详细说明

#### .PARAM — 自定义参数

定义用户常量，用于参数化电路。可在元件值中用 `{name}` 引用。24.1+ 版本大部分情况不需要花括号。可放在子电路内限制作用域。

内置常量：`pi`（π）、`e`（欧拉数）、`k`（玻尔兹曼常数）、`q`（电荷常数）、`true`（1）、`false`（0）。`temp` 为保留名，表示当前温度。

示例：`.PARAM Rval=1k Cval=10n`（电阻值设为 `{Rval}`）

#### .STEP — 参数扫描

重复执行分析，每次改变参数值。可扫描温度、模型参数、全局参数、独立源。可嵌套最多 3 层（波形查看器限制）。

另支持 `.STEP <item> list <value> [...]`（列表值）和 `.STEP <item> file=<filename>`（从文件读取）。

示例：`.STEP PARAM Rval 1k 10k 1k`（扫描 Rval 从 1k 到 10k）

波形查看器中显示多条曲线。

#### .TEMP — 温度扫描

设置仿真温度，等效于 `.STEP temp list <T1> <T2> ...`。温度影响元件模型参数（如电阻温度系数、PN 结 Is）。

示例：`.TEMP 0 27 50 100`

#### .IC — 设置初始条件

设置节点电压/电感电流的初始值。支持 .OP/.TRAN/.AC/.NOISE/.TF 仿真（.DC 扫描中被忽略）。

需配合 `.TRAN ... UIC` 才会真正作为瞬态起点，否则先算直流工作点会覆盖。

示例：`.IC V(out)=5V I(L1)=10mA`

#### .MEASURE — 测量电气量

在仿真结果中测量用户定义的电气量。支持单点测量（FIND/DERIV/PARAM + WHEN/AT）和区间测量（AVG/MAX/MIN/PP/RMS/INTEG + TRIG/TARG）。

结果在日志中查看。

示例：`.MEAS TRAN t_rise TRIG V(out)=1 RISE=1 TARG V(out)=9 RISE=1`（测量上升时间）

#### .MODEL — 定义 SPICE 模型

定义二极管、晶体管、开关、传输线等元件的模型参数。

模型类型：D（二极管）、NPN/PNP（BJT）、NJF/PJF（JFET）、NMOS/PMOS（MOSFET）、NMF/PMF（MESFET）、SW/CSW（电压/电流控制开关）、URC（均匀分布 RC 线）、LTRA（有损传输线）。

示例：`.MODEL mydiode D (Is=1n Rs=0.1 N=1.5)`

#### .SUBCKT — 定义子电路

定义可复用的子电路模块，以 `.ENDS` 结束。用 `X<name> <nodes> <subcktname>` 调用。可参数化。

示例：`.SUBCKT myamp in out VCC ... .ENDS myamp`

#### .LIB — 包含模型库

包含库文件中的模型定义。支持 `.LIB <filename> [<entryname>]` 选择库中特定段。

搜索路径：当前网表目录 → 用户库目录 → 自定义搜索路径 → LTspice 内置库。

示例：`.LIB opamp.lib OP07`

#### .GLOBAL — 声明全局节点

声明子电路中的某些节点为全局节点。注意：节点 "0"（地）是全局公共端，不需要声明；`$G_` 开头的节点名也是全局节点，不需要声明。

示例：`.GLOBAL VDD VCC`

#### .SAVE — 限制保存数据量

只保存指定的节点电压/元件电流，减小 .raw 文件大小。支持通配符 `*` 和 `?`，支持层次化 `:` 语法（如 `V(x23:*)`）。

示例：`.SAVE V(out) I(R1) V(*)`

#### .NODESET — 初始直流解提示

为直流工作点计算提供初始猜测，辅助收敛。与 .IC 不同：.NODESET 只是猜测，迭代后会修正；.IC 配合 UIC 是强制初始值。

示例：`.NODESET V(out)=0V`

#### .FUNC — 用户自定义函数

定义可在表达式中使用的函数。可放在子电路内限制作用域。使用动态作用域。

示例：`.FUNC myfunc(x,y) {sqrt(x*x+y*y)}`

---

## 十三、命令行开关（Command Line Switches）

> 通过命令行启动 LTspice 时附加参数，适用于批处理、自动化仿真、CI 集成等场景。
> macOS 下通过 `open -a LTspice --args <参数>` 或直接调用可执行文件使用。

| 参数 | 功能 |
|---|---|
| `-alt` | 设置求解器为 Alternate 模式（可被网表 .OPTIONS 覆盖） |
| `-ascii` | 使用 ASCII 格式 .raw 文件（人类可读，但严重降低性能和增大文件） |
| `-b <command>` | 批处理模式，可组合 -run/-netlist/-sync，如 `... -b -run` |
| `-big` 或 `-max` | 以最大化窗口启动 |
| `-encrypt` | 加密模型库（第三方库保护，用户可使用但看不到实现细节） |
| `-FastAccess` | 批量将二进制 .raw 文件转换为 Fast Access 格式（加速大数据波形浏览） |
| `-FixUpSchematicFonts` | 转换旧版原理图文本字体大小字段为现代默认值 |
| `-FixUpSymbolFonts` | 转换旧版符号字体大小字段为现代默认值 |
| `-ini <path>` | 指定使用的 .ini 配置文件路径（替代默认配置） |
| `-I<path>` | 添加符号/文件搜索路径（必须是最后一个参数，`-I` 和路径间**无空格**） |
| `-netlist` | 批量将原理图（.asc）转换为 SPICE 网表（.net） |
| `-norm` | 设置求解器为 Normal 模式（可被网表 .OPTIONS 覆盖） |
| `-PCBnetlist` | 批量将原理图转换为 PCB 格式网表 |
| `-run` | 打开命令行指定的原理图后**自动开始仿真** |
| `-sync` | 更新元件库（Update component libraries） |
| `-uninstall` | 卸载 LTspice |

**语法**：`LTspice.exe -I<path> <schematic.asc> -b -run -ini <path>`

**常用示例**：
```bash
# 批处理仿真（不打开 GUI）
ltspice -b mycircuit.asc

# 打开原理图并自动开始仿真
ltspice -run mycircuit.asc

# 原理图转网表
ltspice -netlist mycircuit.asc

# 更新元件库
ltspice -sync
```

---

## ⚠️ 特别注意事项

1. **快捷键仅在英文输入法下生效**：中文输入法下字母键会被输入法拦截，所有单字母快捷键（G/R/C/W/M/S/A 等）均不起作用。使用前请切换到英文输入法（按 `Caps Lock` 或 `⌘+空格` 切换）。

2. **verb-noun 操作模式**：LTspice 是"先动词后名词"接口——先按快捷键选择操作（旋转/镜像/移动/删除等），再点击对象。不要先选中元件再按快捷键。放置元件过程中可直接按 `⌘R`/`⌘E` 旋转/镜像后再放置。

3. **`.` 键 vs `T` 键**：`.options tnom=0` 这类指令必须用 `.` 键放置；用 T 放的就是注释，仿真时被忽略。`⌥+左键` 可切换已有文本的指令/注释属性。

4. **SPICE 指令以 `.` 开头**才合法；注释、空行、`*` 开头行都不会执行。

5. **验证指令是否生效**：跑完仿真 → **⌘L** 看日志。如 `.options tnom=0` 生效，日志会显示 `tnom = 0`（默认 27）。

6. **`.asc` 与 `.net` 是单向转换**：原理图 → 自动生成网表；手写的 .net 内容不会回写原理图，重新生成会**覆盖丢失**。

7. **电流源（I/G 源）输出端必须接负载电阻**到地，否则报 `floating` 错误——电流源不决定节点电压，电压由负载决定。

8. **受控源字母记忆**：E、G 是**电压控制**（VCVS/VCCS），F、H 是**电流控制**（CCCS/CCVS）；增益是乘法，H 源增益乘的是**电流**（V = 增益 × I）。

9. **`temp` vs `tnom`**：`temp` 是仿真环境温度，`tnom` 是元件参数标定温度（默认 27℃）。想改基准用 `.options tnom=...`。

10. **电容 `ic=1V`（初始条件）**：在 .IC 指令中设置，配合 `.tran ... UIC` 才会真正作为瞬态起点，否则先算直流工作点会覆盖它。

11. **⌘L 的日志文件**同时保存在网表同目录的 `.log` 文件中，可直接用文本编辑器查看。

12. **Duplicate 复制不需要 ⌘V**：同一窗口内按 `⌘C` → 点元件 → 点左键放置即可。`⌘V` 仅用于跨原理图窗口粘贴。

13. **画导线按住 ⌘**是临时切换正交吸附（允许任意角度），**画图形按住 ⌘**是禁用网格吸附（自由定位），两者行为不同。

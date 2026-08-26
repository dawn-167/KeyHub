# Changelog

所有重要变更都记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.3.4] - 2026-08-26

### LTspice 指南全面重写（基于官方 26 版快捷键速查表 PDF）

对照官方 `LTspice_Keyboard_Shortcuts.pdf`（4 页，Mac 版默认配置），对 `guides/ltspice.md` 进行了全面重写：

**分类重构**（参考官方 PDF 的分类方式）：
- 放置元件（Place Components）
- 通用编辑（General Editing，含缩放/撤销/删除/移动/旋转等）
- 原理图选项（Schematic Options，正交线/离格/隐藏引脚等）
- 探针操作（Probe Schematic，电压/电流/功率/差分）
- 仿真控制（Simulator）
- 波形查看（Waveform Viewing）
- 波形平移与光标（Waveform Pan & Cursor）
- 符号编辑器绘图（Drawing）
- 网表编辑器 / 文本输入框
- SPICE 分析指令 / SPICE 控制指令
- 命令行开关 / .OPTIONS 参数

**快捷键修正（Mac 版 ⌘/⌥/⇧）**：
- 所有 Windows 风格的 Ctrl/Alt 改为 Mac 版 ⌘/⌥（如 ⌘R 旋转、⌥R 运行、⌘Z 撤销、⌘⇧Z 重做）
- 删除不存在的 `Ctrl+-`（缩放返回）
- `Shift+Z` 从"缩放返回"修正为"缩小（Zoom Out）"
- 删除 `Ctrl+V` 粘贴（同一窗口内 Duplicate 模式不需要，⌘V 仅用于跨窗口）
- 删除 `Ctrl+H` 停止仿真（官方 PDF 中仿真停止为 ⌥S）
- 补充 `0` 重置仿真波形 T=0
- 补充 `⌥+左键` 切换指令/注释
- 补充 `⌘X 或 , 或 Backspace` 删除
- 波形查看器补充 `P` 上方添加窗格、`⇧S` 选择 Step、`⌘C 或 Esc` 清除光标
- 波形查看器修正 `⌘+单击轨迹标签`=高亮网络、`⌥+单击轨迹标签`=积分
- 新增「波形平移与光标」分区，详细列出方向键/修饰键组合的平移和光标跳转行为

**符号编辑器重写**：
- 删除不准确的快捷键（L=画线、R=画矩形、C=画圆、A=画弧线、P=放置引脚等，这些与原理图编辑器冲突）
- 改为菜单操作列表（Draw > Line/Rectangle/Ellipse/Arc、Edit > Add Pin/Port 等），用键帽显示菜单路径
- 标注符号编辑器与原理图编辑器共享单字母快捷键，建议通过菜单访问绘图工具

**SPICE 指令修正与补充**：
- .TRAN 补充完整参数（uic/steady/nodiscard/startup/step/loadstate/savestate/savestatetime）
- .AC/.DC/.NOISE 补充 list 和 file= 形式
- .FOUR 补充 Nharmonics/Nperiods 参数
- .TF 补充 I(Vsource) 形式
- .SAVE 补充通配符 `*`/`?` 和层次化 `:` 语法
- .IC 修正支持的分析类型（.OP/.TRAN/.AC/.NOISE/.TF，.DC 中被忽略）
- .MODEL 补充完整模型类型列表（D/NPN/PNP/NJF/PJF/NMOS/PMOS/NMF/PMF/SW/CSW/URC/LTRA）
- .GLOBAL 补充节点 "0" 和 `$G_` 前缀无需声明
- .SAVEBIAS/.LOADBIAS 标注已被 .SAVESTATE/.LOADSTATE 取代
- .BACKANNO/.END 标注网表生成器自动添加，勿手动放在原理图上
- .KEEPNODE 标注主要用于 .NOISE
- .OPTIONS 参数表基于官方 PDF 第4页全面修正默认值（gminsteps=25、itl2=50、itl6/srcsteps=25、topologycheck=1 等），补充 pivrel/pivtol/maxstep/solver/topologycheck 等参数

**命令行开关补充**：
- 补充 `-sync`（更新元件库）、`-uninstall`（卸载）
- `-b` 修正为可组合 -run/-netlist/-sync 的批处理模式
- 删除不存在的 `-version`（官方 PDF 中无此开关）

**特别注意事项更新**：
- 补充 verb-noun 操作模式说明
- 补充 Duplicate 复制不需要 ⌘V
- 区分画导线按住 ⌘（切换正交）vs 画图形按住 ⌘（禁用网格）
- 所有快捷键说明改为 Mac 版 ⌘/⌥/⇧

## [0.3.3] - 2026-08-26

### UI 改进

- **分区标题竖线颜色扩展**：从 6 种系统色扩展为 11 种精心挑选的颜色（蓝/紫/绿/橙/红/青/靛蓝/粉/棕/薄荷绿/深青），确保每个分区竖线颜色不同；"特别注意事项"分区强制使用黄色
- **所有分区注意事项统一为大框+序号布局**：普通分区的 notes 不再使用独立 CalloutView，改为与"特别注意事项"一致的 NotesListView（大框+序号键帽+立体分隔线），视觉统一
- **注意事项背景与序号颜色匹配**：NotesListView 的渐变背景和外阴影从固定白色/黑色改为使用当前分区主题色的低透明度（背景 10%→6%，阴影 15%），如紫色分区为淡紫色背景+紫色序号，棕色分区为淡棕色背景+棕色序号
- **组件增强**：`CalloutView` 新增 `accentColor` 参数支持自定义竖线颜色；`NotesListView` 新增 `accentColor` 参数支持自定义序号颜色

## [0.3.2] - 2026-08-26

### BUG 修复

- **修复鼠标操作被误解析为快捷键卡片**：波形查看器的"鼠标操作"表格中，"Ctrl+单击轨迹标签"等内容被 `parseCombo` 错误解析为快捷键组合。GuideParser 新增非快捷键表格识别（`###` 标题含"鼠标操作"/"命令行"/"常用参数"时跳过表格解析），同时 `parseCombo` 过滤含中文字符的 combo，双重保险。
- **修复 tab 选中后不恢复的 BUG**：`alwaysHighlightTitles = ["SPICE 指令"]` 导致"SPICE 指令"永远高亮（淡蓝色背景），点击其他 tab 后它不恢复正常。移除此设置，所有 tab 行为统一：选中时蓝底白字+发光，未选中时灰色文字。
- **修复命令行开关出现在 tab 栏**：命令行开关不是快捷键分类，不应作为独立 tab。将 `## 十、命令行开关` 降级为 `### 命令行开关`，归入 SPICE 指令 section 内，其参数表格也被 GuideParser 跳过解析。

## [0.3.1] - 2026-08-26

### LTspice 指南数据修正与补充

基于 LTspice 官方帮助文档（142 个 HTML 页面）的全面核对，修正和补充了 `guides/ltspice.md`：

**修正**：
- 删除官方未支持的 `.DISTO`（失真分析）和 `.SENS`（灵敏度分析）指令（官方 `dotcommands.htm` 列出的 36 个指令中无此两项）

**新增快捷键/操作**：
- 原理图编辑器：增加 `Ctrl+V` 粘贴、右键退出当前模式
- 原理图编辑器：增加 Ctrl+绘图时禁用网格吸附的提示
- 波形查看器：增加方向键移动附加光标、上下键在 .step/.dc/.temp 多组数据间切换
- 波形查看器鼠标操作：增加 Alt+单击导线=导线电流、双击同一轨迹=单独显示、Ctrl+单击轨迹标签=平均功率、单击元件体=元件电流

**新增章节**：
- 新增「十、命令行开关」章节，覆盖 14 个命令行参数（`-b` 批处理、`-netlist` 转网表、`-PCBnetlist`、`-Run` 自动仿真、`-big`、`-alt`/`-norm`、`-ascii`、`-FastAccess`、`-ini`、`-I`、`-encrypt`、`-FixUpSchematicFonts`、`-FixUpSymbolFonts`）

**新增说明**：
- 顶部标注「基于默认配置，LTspice 支持自定义快捷键」，并提示官方内置速查表入口（Help > Keyboard Shortcut Cheat Sheet）
- 编辑操作部分增加「三种编辑模式」说明（Expert / Assisted / Super Expert）

## [0.3.0] - 2026-08-26

### Nexus 元宇宙接入

- **接入 Nexus 规范**：项目正式成为 Nexus 软件元宇宙的工具类成员
- **Bundle ID 统一**：`com.keyref.app` → `com.nexus.tool.keyhub`
- **URL Scheme**：注册 `nexus-keyhub://`，支持跨应用唤起
- **新增 `nexus.json`**：元宇宙应用身份配置文件
- **新增 `Nexus/SPECIFICATION.md`**：元宇宙开发规范文档（命名/结构/共享组件/UI/构建/通信）
- **新增 `README.md`**：项目说明文档
- **共享基础设施层**：创建 `Sources/Common/`，引入 CommonKit 组件
  - `NXHotKeyManager` — 统一全局热键管理（替代原 HotKeyManager）
  - `NXWindowStyle` — 统一毛玻璃浮动窗口创建
  - `NXStatusItem` — 统一菜单栏项和菜单模板
  - `NXPixelUtils` — 像素对齐工具（frame 取整、contentsScale 同步）
  - `NXURLScheme` — 跨应用 URL Scheme 通信（打开/解析/检测安装）
  - `NXCommon` — 元宇宙元信息和应用分类枚举
- **跨应用唤起**：实现 Nexus 应用间互相打开
  - 注册 URL Scheme `nexus-keyhub://`，支持 `search`、`open` 等深度链接
  - 菜单栏新增"Nexus 应用"子菜单，可打开其他已安装应用
  - 支持 `nexus-keyhub://search?q=xxx` 唤起并搜索
  - 支持 `nexus-keyhub://open?guide=xxx` 唤起并打开指定指南
- **隐私保护**：清理所有文档和配置中的个人隐私信息（移除 author 字段等）
- **构建脚本升级**：`build.sh` 支持 `--clean`、`--no-sign` 参数，增加签名步骤
- **Info.plist 完善**：补充 CFBundleName、URL Types，修正 DisplayName

### 架构重构

- **代码模块化拆分**：将原 2911 行单文件 `main.swift` 拆分为按模块组织的多文件结构
  - `Sources/main.swift` — 应用入口
  - `Sources/App/AppDelegate.swift` — 应用主体
  - `Sources/Models/Models.swift` — 数据模型
  - `Sources/Parsers/GuideParser.swift` — Markdown 解析器
  - `Sources/Views/` — 10 个 UI 组件文件
  - `Sources/Common/` — 4 个共享组件文件

### 删除（无用代码清理）

- `steppedSize()` / `roundToEven()` — 从未调用
- `VersionBadge` 类 — 版本功能已移除，从未实例化
- `ShortcutCardView` 类 — 已被 ComponentCardView 替代
- `makeGrid()` / `searchText(of:)` — 从未调用
- `showNotesPage()` / `backToDetail()` — 从未调用
- `homeSearchChanged()` — 首页无搜索框
- `ShortcutItem.version` / `helpUrl` — 从未使用
- `Sources/App/HotKey.swift` — 迁移至 Common/NXHotKeyManager

### 修复

- `SectionTabView.alwaysHighlightTitles` 未设置的问题

### 数据模型简化

- `GuideParser` 移除版本列解析，第三列合并到功能描述

## [0.2.0] - 2026-08-25

### 新增

- 多软件架构：首页软件卡片网格 + 详情页两级导航
- LTspice 完整快捷键收录（原理图/符号/波形/网表 4 个编辑器）
- SPICE 指令参考（40+ 指令，20 个含详细说明）
- 全局热键 ⌃⌥L 唤出/隐藏
- 菜单栏常驻图标
- 实时搜索过滤
- 分区导航标签
- 注意事项独立展示

### 变更

- 键帽显示官方键名（Ctrl/Alt/Shift），不做 Mac 符号转换
- 所有快捷键卡片统一为 3 列正方形卡片布局
- SPICE 指令卡片点击弹出详细说明窗口

## [0.1.0] - 2026-08-24

### 新增

- LTspice 单软件原型
- 毛玻璃浮动窗口
- 双列网格卡片布局
- 搜索实时过滤

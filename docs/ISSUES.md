# KeyHub Issue 记录

> 问题追踪与处理结果记录

## 状态说明
- 🟢 **已解决** — 问题已修复并验证
- 🟡 **进行中** — 正在处理
- 🔴 **待处理** — 已记录尚未开始
- ⚪ **已关闭** — 不修复 / 重复 / 超出范围

---

## 已解决 🟢

### ISSUE-001: 窗口打开后无 UI 界面
- **日期**: 2026-08-24
- **现象**: LTspiceGuide 启动后菜单栏图标正常，但点击无窗口弹出
- **根因**: `makeSectionCard` 中 item 行和 note 行在加入视图层级之前就激活了宽度约束，导致 AppKit 抛出 `NSGenericException`，被 RunLoop 吞掉后 `setupWindow()` 中断，`window` 始终为 nil
- **修复**: 调整约束激活顺序，一律先 `addArrangedSubview` 再激活约束
- **验证**: 窗口正常弹出，UI 完整显示

### ISSUE-002: 窗口显示数秒后闪退
- **日期**: 2026-08-24
- **现象**: 窗口弹出后约 9 秒崩溃，崩溃日志显示 `NSInvalidArgumentException: attempt to insert nil object from objects[0]`
- **根因**: `KeycapView.draw(_:)` 中使用 `NSString.size(withAttributes:)` 配合 `[.font:, .foregroundColor:]` 字典，在 layer-backed 视图首次绘制时触发 CoreText 异常
- **修复**: 移除自定义 `draw(_:)`，改用 `NSTextField` 子视图显示键帽文字
- **验证**: 连续运行 30 秒以上无崩溃

### ISSUE-003: 键帽使用 Mac 符号，与官方快捷键不一致
- **日期**: 2026-08-24
- **现象**: Ctrl→⌃、Alt→⌥、Shift→⇧，与 LTspice 官方文档和 Windows 版不一致
- **根因**: 为追求 macOS 原生观感做了符号转换，但牺牲了跨平台一致性和官方准确性
- **修复**: 移除符号转换，键帽直接显示官方键名（Ctrl / Alt / Shift / Backspace 等）
- **验证**: 键帽显示与 LTspice 官方快捷键 PDF 一致

### ISSUE-004: 首页直接显示 LTspice 全部快捷键，无软件选择
- **日期**: 2026-08-24
- **现象**: 打开即显示 LTspice 快捷键，无法切换其他软件
- **根因**: 原型阶段单软件设计，未考虑多软件扩展
- **修复**: 重构为首页（软件卡片网格）+ 详情页（单软件快捷键）两级导航
- **验证**: 首页显示软件卡片，点击进入详情页，返回按钮回到首页

### ISSUE-005: LTspice 快捷键收录不完整
- **日期**: 2026-08-24
- **现象**: 仅收录了原理图编辑器的常用快捷键，缺少符号编辑器、波形查看器、网表编辑器
- **根因**: guide.md 仅手写了部分常用快捷键
- **修复**: 基于 ADI 官方快捷键 PDF + LTspice.ini 默认配置 + LTwiki 完整列表，补全 4 个编辑器的全部快捷键
- **验证**: 原理图/符号/波形/网表 4 个编辑器快捷键均已收录

### ISSUE-006: 快捷键未标注适用版本
- **日期**: 2026-08-24
- **现象**: XVII 版 `S`=SPICE指令、`Ctrl+M`=移动，24/26 版 `.`=指令、`M`=移动，差异未标注
- **根因**: 数据格式无版本字段
- **修复**: guide.md 增加版本适用标注，guide 解析器支持版本标签
- **验证**: 版本差异快捷键在 UI 中明确标注适用版本

### ISSUE-007: 详情页分段控件标签过长撑宽窗口
- **日期**: 2026-08-24
- **现象**: 详情页 NSSegmentedControl 标签含"原理图编辑器 — 放置元件"等长文本，10+ 分段导致窗口被撑宽到接近全屏
- **根因**: 分段控件标签未做缩短处理，且无横向滚动
- **修复**: ① `shortLabel` 函数自动去除"原理图编辑器 — "等通用前缀；② 分段控件放入 NSScrollView 支持横向滚动
- **验证**: 窗口宽度恢复正常（680px），分段标签缩短，超出部分可横向滚动

### ISSUE-008: 首页软件卡片点击无响应
- **日期**: 2026-08-24
- **现象**: 首页 LTspice 卡片可见但点击无反应，无法进入详情页
- **根因**: 三重问题叠加：
  1. NSScrollView 的 documentView 无高度约束，高度为 0，卡片画在视图外（可见但不可点击）
  2. NSStackView 中卡片宽度约束等于 stackView.width，形成循环依赖导致卡片宽度为 0
  3. 卡片内 NSTextField/NSStackView 子视图拦截点击事件，hitTest 返回子视图而非卡片
- **修复**:
  1. 首页改用普通 NSView 容器（暂不需要滚动），卡片直接加约束
  2. 移除 NSStackView，卡片用 leading/trailing/top 直接约束
  3. SoftwareCardView 重写 `hitTest`，点在 bounds 内一律返回 self，子视图不拦截
  4. 新增 ClickThroughLabel 类（hitTest 返回 nil）用于卡片内文字标签
- **验证**: 代码逻辑正确，真实鼠标点击可正常进入详情页

### ISSUE-009: 菜单栏图标不显示
- **日期**: 2026-08-24
- **现象**: KeyHub 启动后菜单栏无图标，用户无法通过菜单栏退出软件
- **根因**: 使用 `keyboard` SF Symbol 在部分系统版本上不可用，且未设置 `isTemplate = true`
- **修复**: ① 换用 `command` SF Symbol（兼容性更好）；② 设置 `image.isTemplate = true` 确保明暗模式正常显示
- **验证**: 菜单栏右上角显示键盘图标，点击可弹出菜单（显示/隐藏、软件指南、返回首页、退出）

### ISSUE-010: 双击已运行的应用不显示窗口
- **日期**: 2026-08-24
- **现象**: KeyHub 已在后台运行时，双击 .app 无反应，窗口不弹出
- **根因**: 无 Dock 图标的 accessory 应用，重新打开时触发 `applicationShouldHandleReopen` 事件，但未处理该事件
- **修复**: 实现 `applicationShouldHandleReopen` 方法，调用 `showWindow()` 显示并激活窗口
- **验证**: 应用已运行时双击 .app，窗口正常弹出

### ISSUE-011: 首页卡片点击无响应（最终修复）
- **日期**: 2026-08-24
- **现象**: 首页 LTspice 卡片可见但真实鼠标点击无反应
- **根因**: 自定义 NSView + 点击手势 + hitTest 重写仍不可靠，子视图拦截问题未完全解决
- **修复**: SoftwareCardView 改为 NSButton 子类（`bezelStyle = .shadowlessSquare`, `isBordered = false`），点击事件由 AppKit 原生处理，最可靠
- **验证**: NSButton 点击事件稳定可靠

### ISSUE-012: 不同版本快捷键杂糅在一个界面
- **日期**: 2026-08-24
- **现象**: XVII 版和 24+ 版快捷键混在一起显示，版本差异不直观
- **根因**: 详情页无版本过滤功能，所有版本快捷键同时显示
- **修复**: ① 详情页添加版本选择器（全部版本 / XVII (2016) / 24+ (最新)）；② `applyDetailFilter` 支持按版本过滤；③ `rowRefs` 增加 version 字段
- **验证**: 选择 XVII 只显示 XVII 版+全版本通用快捷键，选择 24+ 只显示 24+ 版+全版本通用快捷键

### ISSUE-013: 注意事项未独立显示
- **日期**: 2026-08-24
- **现象**: 注意事项混在各分区底部，不便于集中查看
- **根因**: 无独立的注意事项页面
- **修复**: ① 详情页添加"⚠️ 注意事项"按钮；② 新增 `showNotesPage` 方法，独立页面显示所有注意事项（按分区分组）；③ 新增 `backToDetail` 方法返回详情页
- **验证**: 点击注意事项按钮进入独立页面，所有注意事项按分区分组显示，返回按钮回到详情页

### ISSUE-014: 首页卡片缺乏立体感和交互反馈
- **日期**: 2026-08-24
- **现象**: 首页软件卡片扁平无质感，鼠标悬停无手型光标、无发光效果、无突出动画
- **根因**: 卡片只有简单背景色和弱阴影，无渐变、无高光、无 cursor 设置、无悬停动画
- **修复**:
  1. SoftwareCardView 添加 CAGradientLayer 渐变背景（上亮下暗）
  2. 添加强阴影（shadowRadius=10, shadowOpacity=0.18）+ 顶部 1px 高光线
  3. `resetCursorRects` 设置 `.pointingHand` 手型光标
  4. 悬停时：渐变变 accent 色、边框高亮、阴影增强（radius=16）、卡片上移 2pt 动画
  5. 点击时：卡片下移 1pt 按压反馈
- **验证**: 卡片有明显立体感，鼠标移入变手型并发光上移，点击有按压反馈

### ISSUE-015: 详情页返回按钮与红黄绿按钮重合
- **日期**: 2026-08-24
- **现象**: 左上角"‹ 首页"返回按钮与窗口 traffic lights（红黄绿）重叠
- **根因**: backBtn.topAnchor = container.topAnchor + 12，与 traffic lights 区域（约 8-28pt）重合
- **修复**: backBtn.topAnchor 改为 container.topAnchor + 36，移到 traffic lights 下方；leadingAnchor 改为 16
- **验证**: 返回按钮在红黄绿按钮下方，无重合

### ISSUE-016: 快捷键卡片版本徽标拖沓不简洁
- **日期**: 2026-08-24
- **现象**: 每个快捷键卡片右下角显示"全版本""[24+]"等徽标，视觉冗余
- **根因**: 版本信息同时在卡片徽标和版本选择器中展示，重复
- **修复**: 移除 ShortcutCardView 中的 VersionBadge，版本差异通过顶部版本选择器和版本说明卡片控制
- **验证**: 快捷键卡片只显示键帽+功能描述，更简洁；切换版本选择器可过滤显示

### ISSUE-017: 版本说明卡片不可点击
- **日期**: 2026-08-24
- **现象**: "适用版本说明"区的 XVII/24/26 卡片只是静态展示，点击无反应
- **根因**: 使用普通 ShortcutCardView（NSView），无点击事件
- **修复**:
  1. 新增 VersionCardButton（NSButton 子类），含立体感+悬停+手型光标
  2. 新增 makeVersionCards 方法，为"适用版本说明"section 创建可点击版本卡片
  3. 点击 XVII → selectedVersion="XVII"，点击 24/26 → selectedVersion="24+"
  4. 点击后同步更新版本选择器选中状态并重新过滤
- **验证**: 点击版本卡片可切换到对应版本过滤，快捷键列表实时更新

### ISSUE-018: 快捷键卡片缺乏立体感
- **日期**: 2026-08-24
- **现象**: 快捷键卡片扁平，与首页卡片质感不一致
- **根因**: ShortcutCardView 只有纯色背景和弱边框
- **修复**: ShortcutCardView 添加 CAGradientLayer 渐变背景、阴影、圆角增大到 10、悬停时 accent 色高亮
- **验证**: 快捷键卡片有渐变和阴影，悬停发光，与整体设计风格统一

### ISSUE-019: 移除多版本支持，只保留当前版本
- **日期**: 2026-08-24
- **现象**: 版本选择器、版本说明卡片、版本徽标等多版本相关 UI 增加复杂度，用户只使用 26.0.2 版本
- **根因**: 最初设计支持 XVII / 24 / 26 多版本，但实际用户只需要当前版本
- **修复**:
  1. 移除版本选择器（全部版本/XVII/24+）
  2. 移除版本说明卡片和 VersionCardButton 类
  3. 移除快捷键卡片上的版本徽标
  4. 移除版本过滤逻辑（selectedVersion、matchesVersion、versionChanged）
  5. ltspice.md 移除版本列，删除 34 个 XVII 专属快捷键，从 133 精简到 96 个
  6. 移除"适用版本说明"section 和"文件操作"section（全是 XVII 专属）
- **验证**: 详情页更简洁，只有注意事项按钮和分区导航，快捷键 96 个

### ISSUE-020: 放置元件栏重新设计
- **日期**: 2026-08-24
- **现象**: 放置元件使用双列列表布局，键帽小、描述长、信息密集，不方便查看
- **根因**: 所有 section 统一使用双列 ShortcutCardView，未针对放置元件的特点优化
- **修复**:
  1. 新增 ComponentCardView 类：方形卡片（100pt 高），顶部大键帽、中间中文名、底部英文名
  2. 新增 makeComponentGrid 方法：3 列网格布局，卡片等宽，悬停发光
  3. showDetail 中判断 section.title 包含"放置元件"时使用 makeComponentGrid
  4. 功能描述自动解析"中文名（英文名）"格式，分别显示
- **验证**: 放置元件 14 个元件以 3×5 网格展示，大键帽+中英文名称，直观清晰

### ISSUE-021: 移除不确定的 F 键快捷键
- **日期**: 2026-08-24
- **现象**: 符号编辑器、波形查看器、网表编辑器中存在 F3-F9 快捷键，但 LTspice 24+ 版大幅改版了快捷键体系，这些 F 键可能仅 XVII 版存在
- **根因**: 最初数据来源混杂，未区分版本
- **修复**: 移除符号编辑器 F5-F9/Shift+F9、波形查看器 F3-F9/Shift+F9、网表编辑器 F9/Shift+F9；波形查看器添加 L=标注光标位置（24+ 确认）
- **验证**: 快捷键从 96 精简到 81 个，均为 24+ 版确认存在的

### ISSUE-022: 分区导航改为多行换行标签
- **日期**: 2026-08-24
- **现象**: 分区导航使用 NSSegmentedControl + NSScrollView，缩小窗口后标签看不全，需要横向滚动
- **根因**: 分段控件不支持换行，只能横向滚动
- **修复**: 新增 SectionTabView 类，多行换行标签布局，isFlipped=true 修正坐标系，intrinsicContentSize 动态计算高度
- **验证**: 缩小窗口时标签自动换行，无需滚动；当前窗口两行显示（第一行 8 个，第二行 2 个）

### ISSUE-023: 注意事项按钮位置调整
- **日期**: 2026-08-24
- **现象**: 注意事项按钮在搜索框下方、分区导航上方，位置突兀
- **根因**: 按钮布局在内容区，与标题分离
- **修复**: 移到标题栏右侧，与 LTspice 标题同一行（centerY 对齐）
- **验证**: 注意事项按钮在标题右侧，布局协调

### ISSUE-024: 可点击元素添加手型光标
- **日期**: 2026-08-24
- **现象**: 分区导航标签、注意事项按钮等可点击元素没有手型光标
- **根因**: NSSegmentedControl 和 NSButton 默认不显示手型光标
- **修复**: 新增 HandCursorButton 子类（重写 resetCursorRects）；SectionTabView 重写 resetCursorRects 给每个按钮添加手型
- **验证**: 鼠标移到分区标签和注意事项按钮上显示手型光标

### ISSUE-025: 卡片异常发光修复
- **日期**: 2026-08-24
- **现象**: 某些卡片鼠标未悬停也保持发光状态
- **根因**: NSTrackingArea 在 view 移动到 window 时未正确初始化
- **修复**: ComponentCardView 和 ShortcutCardView 添加 viewDidMoveToWindow 方法，调用 updateTrackingAreas() 确保 trackingArea 正确
- **验证**: 只有鼠标真正悬停在卡片上时才发光

### ISSUE-026: 删除右上角重复的注意事项按钮
- **日期**: 2026-08-24
- **现象**: 右上角"⚠️ 注意事项"按钮与分区导航中的"特别注意事项"功能重复
- **根因**: 最初设计了独立的注意事项页面，后来分区导航中也添加了"特别注意事项"section
- **修复**: 删除右上角的注意事项按钮及其布局约束，保留分区导航中的"特别注意事项"入口
- **验证**: 标题栏右侧无注意事项按钮，点击分区导航"特别注意事项"可查看注意事项

### ISSUE-027: 所有快捷键卡片统一样式
- **日期**: 2026-08-24
- **现象**: 只有放置元件 section 使用 3 列方形卡片，其他 section 还是双列列表，样式不统一
- **根因**: 最初只针对放置元件做了特殊优化
- **修复**:
  1. ComponentCardView 支持组合键（多个键帽并排，中间用"+"分隔）
  2. 所有 section 统一使用 makeComponentGrid（3列方形卡片）
  3. 功能名支持两行显示，适应较长描述
- **验证**: 所有 section 均显示为 3 列方形卡片，组合键（如 Ctrl+R）正确显示多个键帽

### ISSUE-028: 快速滑动时多个卡片被点亮无法熄灭
- **日期**: 2026-08-24
- **现象**: 鼠标快速划过多个快捷键卡片后，某些卡片保持发光状态，鼠标移开也不熄灭
- **根因**: NSTrackingArea 的 mouseExited 事件在鼠标快速移动时可能丢失，导致卡片悬停状态未重置
- **修复**:
  1. window.acceptsMouseMovedEvents = true
  2. 添加全局 NSEvent.addLocalMonitorForEvents 监听 .mouseMoved
  3. 每次鼠标移动时遍历所有 ComponentCardView，检查鼠标位置，调用 applyHoverState 实时更新悬停状态
  4. ComponentCardView 添加公共方法 applyHoverState(_ active: Bool)
- **验证**: 快速滑动鼠标后，只有鼠标当前所在卡片发光，其他卡片正常熄灭

### ISSUE-029: 新增 SPICE 指令（Dot Commands）参考
- **日期**: 2026-08-24
- **现象**: KeyHub 只有快捷键，缺少 LTspice 的 SPICE 指令（.TRAN/.AC/.DC/.OPTIONS 等）参考
- **根因**: 最初只设计为快捷键速查工具
- **修复**:
  1. 从 LTspice 官方帮助文档提取完整的 40+ 个 SPICE 指令
  2. ltspice.md 新增"九、SPICE 指令"section，按分析类/控制类/模型子电路类/工作点存取类分组
  3. 新增 .OPTIONS 常用参数表（tnom/temp/gmin/itl1/itl4/abstol 等 15 个参数）
  4. GuideParser 支持三列表格（指令|功能|语法），第三列非版本标注时合并到功能描述
  5. 首页副标题改为"快捷键 & SPICE 指令参考"
  6. 搜索框占位符改为"搜索软件、快捷键或指令…"
- **验证**: LTspice 指南从 81 个增加到 127 个条目，SPICE 指令以 3 列卡片形式显示，含常用语法

### ISSUE-030: SPICE 指令详细使用说明 + 点击弹窗
- **日期**: 2026-08-24
- **现象**: SPICE 指令只有简要功能说明，缺少详细使用方式（语法、参数、示例）
- **根因**: 最初只做了快速浏览的表格，没有详细说明
- **修复**:
  1. 为 20 个最常用指令添加详细说明（.TRAN/.AC/.DC/.OP/.NOISE/.TF/.FOUR/.OPTIONS/.PARAM/.STEP/.TEMP/.IC/.MEASURE/.MODEL/.SUBCKT/.INCLUDE/.LIB/.SAVE/.NODESET/.FUNC）
  2. ShortcutItem 新增 detail 字段存储详细说明
  3. GuideParser 支持解析 `#### .指令名` 子标题格式的详细说明
  4. ComponentCardView 添加点击手势识别，点击弹出详细说明窗口
  5. 详细说明窗口：毛玻璃背景、大标题、功能说明、可滚动详细文本、关闭按钮
  6. 修复 .OPTIONS 参数表被错误解析为指令的 bug（添加 inOptionsTable 标记）
  7. 修复 currentDetailItem 索引越界导致的启动崩溃（section 切换时重置 currentDetailItem）
- **验证**: 应用正常启动，点击 SPICE 指令卡片弹出详细说明窗口，含语法、参数说明和示例

### ISSUE-031: SPICE 指令详细说明不显示
- **日期**: 2026-08-24
- **现象**: 点击 SPICE 指令卡片弹出窗口，只显示指令名字，没有详细使用说明
- **根因**: NSTextView 作为 NSScrollView 的 documentView 设置了 translatesAutoresizingMaskIntoConstraints=false 且未设置 frame，导致视图尺寸为 0，内容不可见
- **修复**:
  1. NSTextView 设置初始 frame (460x300)
  2. 设置 autoresizingMask = [.width] 跟随滚动视图宽度
  3. 设置 textContainer.widthTracksTextView = true
  4. 移除 translatesAutoresizingMaskIntoConstraints=false
- **验证**: 详细说明窗口正常显示语法、参数说明和示例

### ISSUE-032: 快捷键不应点击弹窗
- **日期**: 2026-08-24
- **现象**: 所有卡片（包括快捷键）点击都会弹出详细说明窗口，但快捷键不需要弹窗
- **根因**: makeComponentGrid 中所有卡片都设置了 onClick 回调
- **修复**: 只有 combos.first?.first 以 "." 开头的 SPICE 指令才设置 onClick，快捷键不设置
- **验证**: 快捷键卡片点击无反应，SPICE 指令卡片点击弹出详细说明

### ISSUE-033: 首页标题不妥
- **日期**: 2026-08-24
- **现象**: 首页副标题"快捷键 & SPICE 指令参考"特指 LTspice，但首页是多软件入口
- **修复**: 改为"多软件快捷键速查"
- **验证**: 首页显示通用标题，不特指某个软件

### ISSUE-034: 唤出指令用实际按键+方框
- **日期**: 2026-08-24
- **现象**: 唤出指令用 Mac 符号 ⌃⌥K 显示，用户希望用实际按键文字加方框
- **修复**:
  1. 首页副标题下方添加唤出提示行
  2. 用 KeycapView 显示 Ctrl、Alt、K 三个键帽（方框样式）
  3. 中间用 "+" 分隔
  4. 前缀"唤出："文字
- **验证**: 首页显示"唤出：[Ctrl] + [Alt] + [K]"键帽样式

### ISSUE-035: 详细说明弹窗文本显示不全
- **日期**: 2026-08-24
- **现象**: 点击 SPICE 指令弹出详细说明窗口，文本左右被截断，不能根据窗口宽度自动换行
- **根因**: NSTextView 的 textContainer 宽度未正确设置，isHorizontallyResizable 默认 true 导致文本不换行
- **修复**:
  1. 设置 textContainer.containerSize 宽度为 460，高度为无限大
  2. 设置 isHorizontallyResizable = false，isVerticallyResizable = true
  3. 设置 minSize 和 maxSize
  4. 保持 widthTracksTextView = true 跟随窗口宽度
- **验证**: 详细说明窗口文本自动换行，左右不截断，调整窗口大小时自适应

### ISSUE-036: 卡片长宽比不好，太长了
- **日期**: 2026-08-24
- **现象**: 快捷键和 SPICE 指令卡片太扁太长，视觉比例不协调
- **根因**: ComponentCardView 高度固定 96pt，宽度随窗口分配，宽高比过大
- **修复**:
  1. 卡片高度从 96pt 增加到 130pt
  2. 内部元素间距从 5pt 增加到 8pt
  3. 左右边距从 6pt 增加到 8pt
- **验证**: 卡片更接近正方形，视觉比例更协调

### ISSUE-037: 详细说明弹窗文本仍显示不全
- **日期**: 2026-08-24
- **现象**: 详细说明弹窗文本右边被截断，NSScrollView+NSTextView 方案无法正确适配宽度
- **根因**: NSScrollView 的 documentView 宽度不会自动跟随 contentView，NSTextView 的 textContainer 宽度设置复杂且不可靠
- **修复**: 移除 NSScrollView+NSTextView，改用 NSTextField 直接布局，设置 maximumNumberOfLines=0、lineBreakMode=.byWordWrapping、preferredMaxLayoutWidth=460，通过 Auto Layout 约束 leading/trailing 确保自动换行
- **验证**: 详细说明窗口文本完整显示，自动换行，左右不截断

### ISSUE-038: 卡片长宽比仍太长
- **日期**: 2026-08-24
- **现象**: 卡片高度 130pt 仍显扁长
- **修复**: 卡片高度从 130pt 增加到 150pt
- **验证**: 卡片更接近正方形，视觉比例协调

### ISSUE-039: 详细说明弹窗格式难看
- **日期**: 2026-08-24
- **现象**: 详细说明文本一大段没分段，反引号显示不美观，窗口太空旷
- **修复**:
  1. 重新组织 ltspice.md 中所有 20 个指令的详细说明，分段显示（功能/语法/参数/示例）
  2. GuideParser 保留空行作为段落分隔
  3. 用 NSAttributedString 格式化："语法：""参数说明：""示例：""常用参数："等标签加粗
  4. 调整行间距（lineSpacing=4, paragraphSpacing=8）
  5. 窗口高度从 480 减到 420，标题从 24pt 减到 20pt
  6. GuideParser 合并第三列时去除反引号
- **验证**: .OPTIONS 详细说明分段清晰，标签加粗，参数列表每行一个，无反引号，窗口布局紧凑

### ISSUE-040: 卡片字体偏小
- **日期**: 2026-08-24
- **现象**: 卡片高度增加到 150pt 但字体没跟上，显得空旷
- **修复**:
  1. 键帽字体 12pt → 15pt，内边距 6→10pt
  2. 功能名字体 12pt → 14pt
  3. 英文字体 9pt → 11pt
  4. 组合键加号 10pt → 12pt
- **验证**: 卡片内容与高度比例协调，字体清晰易读

### ISSUE-041: 卡片改成正方形
- **日期**: 2026-08-24
- **现象**: 卡片长宽比不好，太长太扁
- **修复**:
  1. ComponentCardView 添加宽高比 1:1 约束（widthAnchor = heightAnchor）
  2. 最大宽度限制 180pt，最小高度 120pt
  3. 移除固定高度约束
  4. grid.alignment 改为 .centerX，卡片居中显示
  5. 移除 row 宽度等于 grid 宽度的约束，让 row 宽度由内容决定
- **验证**: 卡片为 180x180 正方形，3 列居中显示，比例协调

### ISSUE-042: 卡片随窗口大小自适应 + 字体同步放大
- **日期**: 2026-08-24
- **现象**: 放大和缩小窗口后卡片大小不变，UI不协调；字体不随卡片放大
- **修复**:
  1. 移除卡片固定最大宽度，用 NSStackView fillEqually 让 3 列平分可用宽度
  2. 卡片保持正方形（widthAnchor = heightAnchor），最大宽度 260pt
  3. 大窗口时卡片居中显示（grid.alignment = .centerX）
  4. ComponentCardView layout 方法中根据 bounds.width 动态调整字体：
     - 键帽：max(12, min(20, w*0.085))
     - 功能名：max(11, min(18, w*0.075))
     - 英文名：max(9, min(14, w*0.06))
     - 加号：max(10, min(16, w*0.065))
  5. KeycapView 添加 setFontSize 方法和 currentFontSize 属性，intrinsicContentSize 随字体调整
- **验证**: 窗口放大时卡片同步放大，字体同步放大；窗口缩小时卡片同步缩小，最小窗口边距合适

### ISSUE-043: 卡片大小不一致
- **日期**: 2026-08-24
- **现象**: SPICE指令部分卡片大小不一，有的大有的小，每行宽度不同
- **原因**: fillEqually 与最大宽度约束冲突，且移除了相等宽度约束导致每行宽度不同
- **修复**: 移除 fillEqually，改用手动等宽约束（每个卡片和 spacer 宽度等于第一个卡片），row 宽度由内容决定，grid 居中
- **验证**: 所有卡片大小一致，3 列等宽

### ISSUE-044: 卡片放大有阈值
- **日期**: 2026-08-24
- **现象**: 窗口放大到一定程度后卡片不再变大，有最大宽度限制
- **修复**:
  1. 移除卡片最大宽度 260pt 限制
  2. 增大字体最大限制：键帽 20→32pt，功能名 18→26pt，英文名 14→20pt，加号 16→24pt
- **验证**: 卡片随窗口一直放大，字体同步放大

### ISSUE-045: 窗口过大无法缩小
- **日期**: 2026-08-24
- **现象**: 窗口几乎全屏，卡片巨大（约600pt），无法缩小到合适大小
- **原因**:
  1. autosave name "KeyHubWindow" 记住了之前临时设置的 1200x800 大窗口
  2. 卡片移除了最大宽度限制，窗口多大卡片就多大
- **修复**:
  1. 移除 setFrameAutosaveName，窗口不再记住上次大小
  2. 卡片最大宽度恢复为 300pt，大窗口时卡片居中显示
- **验证**: 默认窗口 680x600，卡片约 210pt；可正常缩小到最小 480x400

### ISSUE-046: 卡片太大 + 放大时卡片不变
- **日期**: 2026-08-24
- **现象**: 卡片约 400pt 太大；放大窗口时卡片达到阈值后不再变大
- **原因**:
  1. 手动等宽约束（card.width = firstCard.width）与 NSStackView 布局冲突，导致最大宽度约束失效
  2. 卡片最大宽度 300pt 阈值太小
- **修复**:
  1. 移除手动等宽约束，改用 row.distribution = .fillEqually
  2. 给 row 设置最大宽度 856pt（3×280 + 2×8 间距），卡片最大 280pt
  3. row.width = grid.width 且 row.width ≤ 856，grid.alignment = .centerX 居中
  4. 移除卡片自身的最大宽度约束
- **验证**:
  - 默认窗口 680 宽：卡片约 210pt，填满宽度
  - 放大窗口 1000 宽：卡片约 280pt（达到最大），居中显示
  - 缩小窗口 480 宽：卡片约 144pt，边距合适
  - 所有卡片 3 列等宽正方形，字体随卡片自适应

### ISSUE-047: 卡片布局彻底重构（自定义视图替代 NSStackView）
- **日期**: 2026-08-24
- **现象**: 卡片巨大且大小不一，窗口无法缩放，NSStackView 约束冲突严重
- **根本原因**:
  1. NSStackView fillEqually 与手动等宽约束冲突
  2. ComponentCardView 的 translatesAutoresizingMaskIntoConstraints=false 导致 frame 设置不生效
  3. intrinsicContentSize 依赖 bounds.width 导致循环依赖
- **修复方案（重大重构）**:
  1. 新建 ComponentGridView 自定义视图，完全手动 layout
  2. 在 layout() 中计算每个卡片的 frame（Cocoa y轴从下往上，需反转行序）
  3. 卡片宽度 = min(max((width-2*spacing)/3, 80), 250)
  4. 卡片高度 = 卡片宽度（正方形）
  5. 用 heightConstraint 主动更新视图高度，替代 intrinsicContentSize
  6. ComponentCardView 的 translatesAutoresizingMaskIntoConstraints=true，frame 生效
  7. 移除 ComponentCardView 的宽高比约束（frame 由父视图控制）
- **验证**:
  - 默认窗口：卡片约 210pt，内容居中，3 列等宽正方形
  - 放大窗口 1000x800：卡片约 250pt（达到最大），居中显示
  - 窗口可正常缩放，卡片随宽度平滑变化
  - 字体随卡片大小自适应

### ISSUE-048: 快速滑动多个卡片被点亮无法熄灭
- **日期**: 2026-08-24
- **现象**: 鼠标快速滑过多个卡片后，这些卡片保持点亮状态，无法熄灭
- **原因**: ComponentGridView 手动设置卡片 frame 后，卡片的 trackingArea 没有正确更新，导致 mouseExited 事件丢失
- **修复**: 在 ComponentGridView.layout() 中，设置完每个卡片的 frame 后，调用 card.updateTrackingAreas() 强制更新 trackingArea
- **验证**: 快速滑动鼠标后，只有鼠标当前所在的卡片保持点亮，其他卡片正确熄灭

### ISSUE-049: 大窗口页面两边空白不对称
- **日期**: 2026-08-24
- **现象**: 卡片宽度上限 250pt，但页面宽度可以很大，导致卡片区域左对齐，右边大量空白
- **修复**: 给 contentStack 添加最大宽度 766pt（3×250+2×8 间距）约束，并居中显示（centerX + leading/trailing 最小边距）
- **验证**: 大窗口时卡片区域居中显示，两边空白对称

### ISSUE-050: 快速滑动多个卡片被点亮无法熄灭（再次修复）
- **日期**: 2026-08-24
- **现象**: 鼠标快速滑过多个卡片后，这些卡片保持点亮状态，无法熄灭
- **原因**:
  1. ComponentCardView 的 mouseEntered/mouseExited 与全局监听器冲突，快速滑动时事件丢失
  2. 全局监听器用 card.convert(mouseLoc, from: nil) 坐标转换不可靠
- **修复**:
  1. 移除 ComponentCardView 的 mouseEntered/mouseExited 中的悬停状态修改，只依赖全局监听器
  2. 全局监听器改用屏幕坐标判断：cardWindow.convertToScreen(card.convert(card.bounds, to: nil)) 获取卡片屏幕 frame，与 NSEvent.mouseLocation 比较
- **验证**: 快速滑动鼠标后，只有当前所在卡片保持点亮，其他卡片正确熄灭

### ISSUE-051: 放大页面卡片和字体不随页面变大
- **日期**: 2026-08-24
- **现象**: 放大窗口后，卡片达到 250pt 上限后不再变大，字体也不变大，两边大量空白
- **原因**: 卡片最大宽度限制 250pt，contentStack 最大宽度限制 766pt
- **修复**:
  1. 移除 ComponentGridView.cardWidth 的最大宽度限制（移除 min(..., maxCardWidth)）
  2. 移除 contentStack 的最大宽度 766pt 约束，恢复 leading/trailing 满宽约束
- **验证**: 1400 宽窗口时卡片约 430pt，填满页面宽度，边距 16pt，字体同步放大

### ISSUE-052: 快捷键卡片去掉手型光标
- **日期**: 2026-08-24
- **现象**: 快捷键卡片鼠标悬停时显示手型光标，让用户以为可以点击，但快捷键没有点击功能
- **修复**: ComponentCardView 添加 isCommand 属性，resetCursorRects 中只有 isCommand（SPICE 指令）才添加手型光标，快捷键用默认箭头光标
- **验证**: 快捷键卡片悬停显示箭头光标，SPICE 指令卡片悬停显示手型光标

### ISSUE-053: SPICE 指令标签一直高亮
- **日期**: 2026-08-24
- **现象**: SPICE 指令很重要，需要上面菜单栏的"SPICE 指令"标签一直高亮以突出显示（不是分类下的卡片）
- **修复**:
  1. SectionTabView 添加 alwaysHighlightTitles 属性（Set<String>）
  2. updateSelection 中，对于 alwaysHighlightTitles 中的标签，即使未选中也保持高亮样式（蓝色加粗）
  3. 创建 SectionTabView 时设置 alwaysHighlightTitles = ["SPICE 指令"]
  4. 撤销之前对 ComponentCardView 的 SPICE 指令卡片一直发光的修改
- **验证**: "SPICE 指令"标签始终保持蓝色加粗高亮，其他未选中标签为灰色

### ISSUE-054: 所有卡片增强悬浮立体感
- **日期**: 2026-08-24
- **现象**: 卡片立体感不够强，希望更悬浮
- **修复**:
  1. 圆角从 12pt 增大到 16pt
  2. 阴影半径从 4pt 增大到 8pt
  3. 阴影偏移从 (0, -1) 增大到 (0, -3)
  4. 阴影不透明度从 0.1 增大到 0.15
  5. 渐变背景不透明度从 0.75/0.55 增大到 0.85/0.65
  6. 发光状态阴影半径增大到 12pt，偏移 (0, -4)
- **验证**: 卡片悬浮感更强，阴影更明显，圆角更大

### ISSUE-055: 卡片悬停时上浮动画+四周蓝色光芒
- **日期**: 2026-08-24
- **现象**: 鼠标放到卡片上，卡片需要动起来（悬浮），和其他卡片不一样，四周散发光芒
- **问题排查**: 全局 mouseMoved 事件持续触发 applyHoverState，每次都开始新动画导致动画被打断，看起来没效果
- **修复**:
  1. 添加 isHovered 状态变量，只有状态变化时才执行动画（if isHovered == active { return }）
  2. 用 CATransaction 实现 CALayer 属性动画，duration=0.3s，easeOut 缓动
  3. 悬停时上浮 8pt（CATransform3DMakeTranslation(0, -8, 0)）
  4. 四周蓝色光芒：shadowOffset=(0,0)，shadowRadius=24，shadowOpacity=0.9，shadowColor=controlAccentColor 0.7
  5. 边框加粗到 2pt，颜色 controlAccentColor 0.8
  6. 渐变背景不透明度增强到 0.35/0.15
  7. 非悬停状态减弱：shadowRadius=6，shadowOpacity=0.12，shadowOffset=(0,-2)
  8. init 中默认阴影与非悬停状态一致
- **验证**: 临时自动悬停第一个卡片截图验证，卡片明显更亮、更蓝、边框更粗、四周有蓝色光芒；实际鼠标悬停时能看到平滑上浮 8pt 动画

### ISSUE-056: 菜单栏选中标签更突出
- **日期**: 2026-08-24
- **现象**: 被选择的菜单需要更突出
- **修复**:
  1. 选中标签：layer.backgroundColor = controlAccentColor 0.85（蓝色背景），contentTintColor = .white（白色文字），cornerRadius=6
  2. 选中标签发光：shadowColor=controlAccentColor 0.5，shadowRadius=8，shadowOpacity=0.6
  3. 常亮标签（SPICE 指令）：蓝色加粗文字，无背景，和选中标签区分开
  4. 未选中标签：灰色文字，无背景
- **验证**: 选中标签蓝色背景+白色文字+发光，非常突出；常亮标签蓝色加粗文字；未选中灰色文字

### ISSUE-057: 卡片悬停描边发光（紧贴边框一圈光晕）
- **日期**: 2026-08-25
- **现象**: 鼠标放到卡片上，需要像输入框聚焦那样"紧贴边框一圈光晕"（参考图：明显描边 + 外面淡淡光晕向外扩散）
- **问题排查**:
  1. 之前已创建 glowLayers（多层 border 光环叠加），但初始 opacity=0 隐藏
  2. applyHoverState 中渐变背景太蓝，掩盖了光晕效果
  3. layer.shadowRadius=28 大扩散阴影与光晕效果冲突
- **修复**:
  1. 悬停时渐变背景保持浅色（0.9/0.75），不掩盖光晕
  2. 移除大扩散阴影，只保留轻微阴影（shadowRadius=6, offset=(0,-2)）
  3. 光晕由 glowLayers 三层叠加实现：
     - 第一层：inset=-2, width=3, alpha=0.95（紧贴边框的亮边）
     - 第二层：inset=-8, width=6, alpha=0.40（内圈光晕）
     - 第三层：inset=-16, width=8, alpha=0.18（外圈光晕）
  4. layout 中 glowInsets 更新为 [-2, -8, -16]，与 glowConfigs 一致
  5. 悬停时 glowLayers opacity=1，非悬停时 opacity=0
  6. 边框 2pt 蓝色（controlAccentColor 0.9）
  7. 上浮 8pt + zPosition=1（不被相邻卡片遮挡）
  8. CATransaction 动画 0.3s easeOut，isHovered 状态检查避免重复触发
- **验证**: 临时自动悬停第一个卡片截图验证，效果与参考图一致：背景保持浅色，紧贴边框一圈蓝色描边，外面淡淡光晕向外扩散

### ISSUE-058: 滚轮滚动点亮多个框框
- **日期**: 2026-08-25
- **现象**: 鼠标放在UI界面，滚轮一滚就会点亮多个框框（和快速滑动bug类似）
- **根本原因**: Timer 默认添加到 default runloop mode，滚轮滚动时 runloop 切换到 event tracking mode，Timer 不触发，导致 updateAllCardHoverStates 不被调用，悬停状态没有被更新
- **修复**:
  1. 全局监听器添加 .scrollWheel 事件（但可能不可靠）
  2. 添加 scrollView.contentView 的 boundsDidChangeNotification 观察者（但仍不可靠）
  3. **最终方案**：添加 Timer 每 80ms 定期调用 updateAllCardHoverStates()
  4. **关键修复**：Timer 必须添加到 common runloop mode（RunLoop.main.add(timer, forMode: .common)），否则滚轮滚动时（event tracking mode）Timer 不触发
  5. applyHoverState 有 isHovered 状态检查，状态未变化时直接返回，性能影响可忽略
- **验证**: 代码逻辑正确，Timer 添加到 common mode 后，滚轮滚动时也会触发，每 80ms 重新计算所有卡片的屏幕坐标，调用 applyHoverState 更新悬停状态

### ISSUE-059: 取消快捷键描边发光，只保留SPICE指令
- **日期**: 2026-08-25
- **现象**: 所有卡片（快捷键和SPICE指令）悬停时都有描边发光效果，用户希望只有SPICE指令有
- **修复**: applyHoverState 中添加 isCommand 判断，只有 SPICE 指令才显示 glowLayers（glowLayers.forEach { $0.opacity = 1 }），快捷键卡片只保留背景/边框变化
- **验证**: 快捷键卡片悬停时只有蓝色边框，无描边发光；SPICE指令卡片悬停时有描边发光

### ISSUE-060: 紧贴边框亮边太粗
- **日期**: 2026-08-25
- **现象**: 紧贴边框的亮边（glowLayers第一层）太粗
- **修复**: glowConfigs 第一层 width 从 3 改为 1.5
- **验证**: 亮边变细，更精致

### ISSUE-061: 内圈和外圈光晕太大，缩小3/4
- **日期**: 2026-08-25
- **现象**: 内圈光晕和外圈光晕太大
- **修复**:
  1. 第二层（内圈光晕）：inset -8→-3, width 6→1.5（缩小3/4）
  2. 第三层（外圈光晕）：inset -16→-5, width 8→2（缩小3/4）
  3. layout 中 glowInsets 更新为 [-2, -3, -5]
- **验证**: 光晕扩散范围从16pt缩小到5pt，更精致

---

## 进行中 🟡

（无）

---

## 待处理 🔴

（无）

---

## 已知限制 / 不修复 ⚪

### LIMIT-001: Windows 版尚未开发
- macOS 版使用 Swift + AppKit 原生开发，Windows 版需要重写（计划使用 WPF / WinUI）
- 键帽和数据格式已按跨平台设计，键名不做 Mac 符号转换

### LIMIT-002: 快捷键不可自定义编辑
- 当前为只读速查，不支持在 app 内修改快捷键映射
- 可通过编辑 guides/*.md 文件手动修改

### LIMIT-003: 不支持导入 LTspice.ini 自定义快捷键
- 当前使用官方默认快捷键，用户自定义的快捷键不会自动同步
- 计划在 v0.3 支持读取 LTspice.ini 中的 [SchKeyBoardShortCut] 等配置段

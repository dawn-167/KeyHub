# KeyHub 技术文档

> 多软件快捷键速查工具 · macOS 原生应用
> Nexus 元宇宙 · 工具类成员
> 版本：V0.3 | 最后更新：2026-08-26

---

## 一、项目概述

### 1.1 项目背景

KeyHub 是一款 macOS 原生的多软件快捷键速查工具，最初为 LTspice 电路仿真软件的快捷键查询而开发，后演进为支持多软件的通用快捷键速查平台。

**核心价值**：通过全局热键一键唤出，快速查阅目标软件的所有快捷键和 SPICE 指令，无需在软件帮助文档中翻找。

### 1.2 功能特性

- **全局热键唤出**：`⌃⌥L`（Control+Option+L）一键唤出/隐藏，浮动窗口始终置顶
- **多软件支持**：首页卡片式布局，可扩展多个软件的快捷键指南
- **分类浏览**：按功能分区（放置元件、编辑操作、仿真控制等）tab 切换
- **实时搜索**：支持快捷键名称和功能描述的模糊搜索
- **SPICE 指令详情**：点击指令卡片弹出详细使用说明（语法、参数、示例）
- **特别注意事项**：键帽序号+立体分隔线布局，集中展示注意事项

### 1.3 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 语言 | Swift 5 | 原生开发，无第三方依赖 |
| UI 框架 | Cocoa / AppKit | 纯代码布局，无 Storyboard/XIB |
| 全局热键 | Carbon API | `RegisterEventHotKey` 注册系统级热键 |
| 窗口 | NSWindow + NSVisualEffectView | 浮动窗口 + 毛玻璃背景 |
| 构建 | swiftc 命令行 + build.sh | 直接编译，无 Xcode 项目文件 |
| 签名 | codesign | 本地签名确保运行 |

---

## 二、项目结构

### 2.1 目录结构

```
KeyHub/
├── Sources/                    # 源代码（多文件模块化）
│   ├── main.swift              # 应用入口
│   ├── App/
│   │   └── AppDelegate.swift   # 应用主体（窗口、页面、菜单栏）
│   ├── Models/
│   │   └── Models.swift        # 数据模型（ShortcutItem / SectionData / SoftwareGuide）
│   ├── Parsers/
│   │   └── GuideParser.swift   # Markdown 指南解析器
│   ├── Views/
│   │   ├── KeycapView.swift            # 键帽视图
│   │   ├── ComponentCardView.swift     # 快捷键/指令卡片
│   │   ├── ComponentGridView.swift     # 卡片网格（手动 layout）
│   │   ├── SoftwareCardView.swift      # 首页软件卡片
│   │   ├── HomeSoftwareGridView.swift  # 首页卡片网格
│   │   ├── SectionTabView.swift        # 分区标签（多行换行）
│   │   ├── NotesListView.swift         # 注意事项列表
│   │   ├── CalloutView.swift           # 提示气泡
│   │   └── CommonViews.swift           # 小型辅助视图（5个）
│   └── Common/                 # Nexus CommonKit 共享代码
│       ├── NXCommon.swift              # 元宇宙元信息
│       ├── NXHotKeyManager.swift       # 统一全局热键管理
│       ├── NXWindowStyle.swift         # 统一毛玻璃窗口创建
│       ├── NXStatusItem.swift          # 统一菜单栏项
│       └── NXPixelUtils.swift          # 像素对齐工具
├── KeyHub.app/                # 编译产物（git 忽略）
│   └── Contents/
│       ├── MacOS/KeyHub       # 可执行文件
│       ├── Resources/
│       │   ├── AppIcon.icns   # 应用图标
│       │   ├── LTspice.png    # LTspice 软件图标
│       │   └── guides/        # 快捷键数据（运行时加载）
│       └── Info.plist         # 应用配置
├── KeyHub.iconset/            # 图标源文件（各尺寸 png）
├── guides/
│   └── ltspice.md             # LTspice 快捷键数据（Markdown）
├── build.sh                   # 一键编译脚本（Nexus 标准）
├── nexus.json             # Nexus 元宇宙配置
├── CHANGELOG.md               # 更新日志
├── README.md                  # 项目说明
├── docs/                      # 文档
│   ├── TECHNICAL_DOCUMENTATION.md  # 本文档
│   └── ISSUES.md                    # 问题记录
├── ISSUES.md                  # Issue 记录
├── TECHNICAL_DOCUMENTATION.md # 本文档
└── .gitignore                 # Git 忽略配置
```

### 2.2 多文件架构说明

本项目采用**多文件模块化架构**，按职责分层组织代码：

**分层设计**：
- **App/** — 应用生命周期、窗口管理、页面路由
- **Models/** — 数据模型，无 UI 依赖
- **Parsers/** — 数据解析，将 Markdown 转为数据模型
- **Views/** — UI 组件，每个类一个文件（或相关小组件合并）

**优点**：
- 职责清晰，每个文件聚焦单一功能
- 多人协作时合并冲突概率低
- 便于单元测试（Models / Parsers 可独立测试）
- Xcode / VS Code 中文件导航更高效

**编译方式**：`build.sh` 脚本自动收集 `Sources/` 下所有 `.swift 文件，用 `swiftc` 一次编译完成。

---

## 三、核心功能实现

### 3.1 全局热键（Carbon API）

#### 实现原理

macOS 的全局热键需要使用 Carbon API。KeyHub 使用 Nexus CommonKit 共享的 `NXHotKeyManager` 模块，内部通过 `InstallEventHandler` 注册事件处理器，再用 `RegisterEventHotKey` 注册具体热键。热键触发时在 C 回调中切换到主线程执行 UI 操作。

#### 关键代码

```swift
import Carbon.HIToolbox

// 在 AppDelegate 中注册（使用 Nexus 共享 NXHotKeyManager）
NXHotKeyManager.register(
    keyCode: UInt32(kVK_ANSI_L),
    modifiers: UInt32(controlKey) | UInt32(optionKey),
    signature: OSType(0x4B52), // "KR"
    onHotKey: { [weak self] in self?.toggleWindow() }
)

// 应用退出时注销
NXHotKeyManager.unregister()
```

`NXHotKeyManager` 内部实现（`Sources/Common/NXHotKeyManager.swift`）：
- 封装 `InstallEventHandler` + `RegisterEventHotKey` 两步注册
- C 回调函数 `dvHotKeyHandler` 切换到主线程调用闭包
- 提供 `unregister()` 统一注销热键和事件处理器

#### 注意事项

1. **修饰键常量**：Carbon 的 `controlKey`、`optionKey` 等是位掩码，需要用 `|` 组合
2. **键码**：`kVK_ANSI_L` 是字母 L 的虚拟键码，不同键盘布局可能不同
3. **回调必须是全局函数**：Carbon C API 不支持 Swift 实例方法作为回调，需通过 `appDelegateRef` 弱引用桥接到 AppDelegate
4. **线程切换**：C 回调可能在非主线程调用，UI 操作必须 `DispatchQueue.main.async`
5. **应用必须运行**：全局热键只在应用运行时有效，需要将应用设为 `LSUIElement`（无 Dock 图标，后台运行）

### 3.2 浮动窗口 + 毛玻璃背景

#### 实现原理

使用 `NSWindow` 创建浮动窗口，设置 `level = .floating` 使其始终置顶。内容视图使用 `NSVisualEffectView` 实现毛玻璃效果，叠加淡绿色 tint 层统一色调。

#### 关键代码

```swift
// 创建浮动窗口
let win = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 480, height: 730),
    styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
    backing: .buffered, defer: false
)
win.title = "KeyHub"
win.titlebarAppearsTransparent = true  // 透明标题栏
win.titleVisibility = .hidden           // 隐藏标题
win.titlebarSeparatorStyle = .none
win.isOpaque = false                    // 透明背景
win.backgroundColor = .clear
win.hasShadow = true
win.level = .floating                    // 始终置顶
win.isReleasedWhenClosed = false
win.acceptsMouseMovedEvents = true
win.minSize = NSSize(width: 480, height: 400)
win.maxSize = NSSize(width: 480, height: 3000)  // 宽度固定，只允许纵向拉升

// 毛玻璃背景
let vibrancy = NSVisualEffectView(frame: win.contentLayoutRect)
vibrancy.material = .popover       // popover 风格毛玻璃
vibrancy.blendingMode = .behindWindow
vibrancy.state = .active
vibrancy.wantsLayer = true
vibrancy.layer?.cornerRadius = 12
vibrancy.layer?.masksToBounds = true
vibrancy.layer?.borderWidth = 0.5
vibrancy.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
vibrancy.autoresizingMask = [.width, .height]
win.contentView = vibrancy

// 淡绿色叠加层（统一色调）
let greenTint = NSView(frame: vibrancy.bounds)
greenTint.wantsLayer = true
greenTint.layer?.backgroundColor = NSColor(red: 0.75, green: 0.95, blue: 0.80, alpha: 0.15).cgColor
greenTint.autoresizingMask = [.width, .height]
vibrancy.addSubview(greenTint)
```

#### 窗口尺寸设计决策

- **宽度固定 480pt**：确保卡片布局稳定，避免横向拉伸导致排版混乱
- **高度范围 400~3000pt**：只允许纵向拉升，适应不同数量的快捷键显示
- **初始高度 730pt**：正好显示 3 行卡片，视觉舒适

### 3.3 无 Dock 图标后台运行

#### Info.plist 配置

```xml
<key>LSUIElement</key>
<true/>
```

设置 `LSUIElement = true` 后：
- 应用不在 Dock 中显示图标
- 不在 Command+Tab 切换列表中显示
- 只能通过菜单栏图标或全局热键访问

#### 菜单栏图标

```swift
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
if let button = item.button {
    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    let img = NSImage(systemSymbolName: "book.closed",
                      accessibilityDescription: "KeyHub 快捷键手册")?
        .withSymbolConfiguration(config)
    img?.isTemplate = true  // 模板图标，自动适配明暗模式
    button.image = img
    button.imagePosition = .imageOnly
}
```

菜单包含：显示/隐藏、软件指南子菜单、返回首页、退出。

### 3.4 数据结构设计

#### 核心数据模型

```swift
// 单个快捷键/指令
struct ShortcutItem {
    let combos: [[String]]   // 快捷键组合，如 [["Ctrl", "C"]]
                             // 支持多组替代键，如 [["Ctrl+Z"], ["Ctrl+Shift+Z"]]
    let desc: String          // 功能描述，如 "旋转元件（Rotate）"
    var detail: String = ""   // 详细使用说明（SPICE 指令等）
}

// 功能分区
struct SectionData {
    let title: String         // 分区标题，如 "放置元件"
    var items: [ShortcutItem] = []  // 该分区下的快捷键列表
    var notes: [String] = []        // 注意事项
}

// 软件指南
struct SoftwareGuide {
    let name: String          // 软件名称，如 "LTspice"
    let version: String       // 版本号
    let icon: String          // SF Symbol 图标名
    let lastUpdated: String   // 最后更新日期
    let minVersion: String    // 最低适配版本
    let sections: [SectionData] // 所有分区
    var totalShortcuts: Int {  // 计算属性：快捷键总数
        sections.reduce(0) { $0 + $1.items.count }
    }
}
```

#### 数据解析

从 Markdown 文件解析快捷键数据，使用**表格格式**：

```markdown
---
name: LTspice
version: 26.0.2
icon: cpu
last_updated: 2026-08
min_version: 24
---

## 一、原理图编辑器 — 放置元件

| 快捷键 | 功能 |
|---|---|
| G | 接地（Ground） |
| R | 电阻（Resistor） |
| Ctrl+R | 旋转元件（Rotate） |

> 重要提示：`.` 放 SPICE 指令，`T` 放注释。

## 九、SPICE 指令（Dot Commands）

### 分析类指令

| 指令 | 功能 | 常用语法 |
|---|---|---|
| .AC | 小信号交流分析（频响） | `.AC dec 100 1Hz 100MEG` |
| .TRAN | 瞬态分析（时域） | `.TRAN 10u 1m` |

#### .TRAN — 瞬态分析

最常用的仿真类型，计算电路上电后随时间的变化。

语法：.TRAN <Tstep> <Tstop> [Tstart [dTmax]]
示例：.TRAN 1u 1m
```

解析逻辑：
1. `---` 包裹的 YAML frontmatter 解析软件元数据
2. `## ` 开头的行为分区标题
3. `|` 开头的行为表格行，解析快捷键/指令和功能描述
4. `> ` 开头的行为注意事项
5. `#### ` 开头的子标题为指令详细说明，后续文本累积到对应指令的 `detail` 字段
6. 应用启动时自动扫描 `guides/` 目录，加载所有 `.md` 文件

---

## 四、UI 组件设计经验

### 4.1 键帽组件（KeycapView）

#### 设计目标

模拟物理键盘键帽的视觉效果，用于显示快捷键按键。显示官方键名（Ctrl/Alt/Shift），不做 Mac 符号转换，确保跨平台一致性。

#### 实现要点

```swift
final class KeycapView: NSView {
    private let gradientLayer = CAGradientLayer()  // 渐变背景（顶亮底暗，模拟凸起）
    private let topHighlight = CALayer()            // 顶部高光
    private let bottomShadow = CALayer()            // 底部阴影
    private let label = NSTextField(labelWithString: "")

    init(key: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor

        // 渐变背景：顶亮底暗
        gradientLayer.colors = [
            NSColor(white: 0.97, alpha: 1.0).cgColor,
            NSColor(white: 0.86, alpha: 1.0).cgColor
        ]
        layer?.insertSublayer(gradientLayer, at: 0)

        // 外阴影：轻微投影，增加立体感
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        layer?.shadowRadius = 2
        layer?.shadowOpacity = 1
    }

    // 支持自定义背景色（用于序号键帽等特殊场景）
    func setTintColor(_ color: NSColor) {
        let light = color.blended(withFraction: 0.3, of: .white) ?? color
        let dark = color.blended(withFraction: 0.15, of: .black) ?? color
        gradientLayer.colors = [light.cgColor, dark.cgColor]
    }
}
```

#### 尺寸自适应

键帽宽度根据文字内容自适应：
```swift
override var intrinsicContentSize: NSSize {
    let font = NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
    let w = (label.stringValue as NSString).size(withAttributes: [.font: font]).width
    let h = max(22, currentFontSize * 1.7)
    return NSSize(width: max(ceil(w) + 14, 28), height: h)
}
```

**最小宽度 28pt**：确保即使单个字符也有合适的键帽大小。

### 4.2 卡片组件（ComponentCardView）

#### 设计目标

显示单个快捷键/指令的卡片，包含键帽、功能名、英文名三行内容。正方形卡片，3 列网格布局。

#### 布局结构

```
┌─────────────────────┐
│      [键帽行]       │  ← 居中，如 Ctrl+R 或 .AC
│                     │
│    功能中文名       │  ← 居中，如 "旋转元件"
│                     │
│    英文描述         │  ← 居中，如 "Rotate"
└─────────────────────┘
```

#### 跨列布局

当内容较长时，卡片可跨2列显示，避免文字截断：

```swift
private func shouldSpan(_ card: ComponentCardView) -> Bool {
    // 1. 键帽宽度超过单列内容宽度
    if keyRowWidth > contentWidth { return true }
    // 2. 中文超过2行
    if nameLineCount > 2 { return true }
    // 3. 英文超过2行
    if enLineCount > 2 { return true }
    // 4. 中文+英文总行数>=3（避免单列太挤）
    if nameLineCount + enLineCount >= 3 { return true }
    // 5. 总高度超过卡片高度
    return totalHeight > contentHeight
}
```

#### 智能紧凑排列

网格布局时，当前行剩1列时优先从后面找普通卡片填上，不留空洞：

```swift
while !remaining.isEmpty {
    // 找第一个能放进当前行剩余空间的卡片
    var foundIdx = -1
    for (i, card) in remaining.enumerated() {
        let span = shouldSpan(card) ? 2 : 1
        if currentCol + span <= cols {
            foundIdx = i
            break
        }
    }
    if foundIdx == -1 {
        currentCol = 0  // 当前行放不下任何卡片，换行
        rows.append((y: 0, cards: []))
        continue
    }
    // ...放置卡片
}
```

#### 悬停效果区分

- **快捷键卡片**：悬停时仅背景/边框轻微变化，无手型光标
- **SPICE 指令卡片**：悬停时上浮 8pt + 蓝色描边发光 + 手型光标，点击弹出详细说明

### 4.3 首页卡片彩虹发光效果

#### 设计目标

鼠标悬停时，卡片从背面散发出彩虹色光晕，配合呼吸脉冲动画。

#### 实现要点

```swift
// 彩虹渐变层（放在卡片背面）
let rainbowGlow = CAGradientLayer()
rainbowGlow.colors = [
    NSColor(red: 1.0, green: 0.75, blue: 0.75, alpha: 1.0).cgColor,
    NSColor(red: 1.0, green: 0.88, blue: 0.65, alpha: 1.0).cgColor,
    NSColor(red: 0.92, green: 1.0, blue: 0.75, alpha: 1.0).cgColor,
    NSColor(red: 0.75, green: 1.0, blue: 0.85, alpha: 1.0).cgColor,
    NSColor(red: 0.75, green: 0.92, blue: 1.0, alpha: 1.0).cgColor,
    NSColor(red: 0.85, green: 0.8, blue: 1.0, alpha: 1.0).cgColor,
]
rainbowGlow.cornerRadius = 22
rainbowGlow.opacity = 0

// 高斯模糊滤镜，消除硬边界
if let blur = CIFilter(name: "CIGaussianBlur") {
    blur.setValue(10, forKey: "inputRadius")
    rainbowGlow.filters = [blur]
}
// 柔和光晕：大半径 shadow 模拟模糊发光
rainbowGlow.shadowRadius = 18
rainbowGlow.shadowOpacity = 0.85

layer?.insertSublayer(rainbowGlow, below: gradientLayer)  // 放在卡片背面

// 呼吸脉冲动画
let pulseAnim = CABasicAnimation(keyPath: "opacity")
pulseAnim.fromValue = 0.4
pulseAnim.toValue = 0.6
pulseAnim.duration = 2.0
pulseAnim.autoreverses = true
pulseAnim.repeatCount = .infinity
rainbowGlow.add(pulseAnim, forKey: "breathing")
```

#### 关键经验

1. **层级顺序**：彩虹层必须 `insertSublayer(below:)` 卡片内容层，否则会覆盖文字
2. **frame 要比卡片大**：`insetBy(dx: -10, dy: -10)`，让光晕从卡片边缘溢出
3. **高斯模糊**：必须加 `CIGaussianBlur` 滤镜，否则会有明显的硬边界
4. **呼吸动画**：opacity 0.4↔0.6，2秒周期，模拟发光呼吸效果
5. **悬停时才显示**：默认 opacity=0，mouseEntered 时设为 0.5 并启动动画

### 4.4 立体分隔线（SeparatorView）

#### 设计目标

在特别注意事项列表中，用立体的线分隔每条注意事项，增加层次感。

#### 实现原理

用双 CALayer 模拟凸起效果：
- 上层：0.5pt 深色（阴影）
- 下层：0.5pt 浅色（高光）

```swift
final class SeparatorView: NSView {
    private let shadowLine = CALayer()
    private let highlightLine = CALayer()

    override func layout() {
        super.layout()
        shadowLine.frame = NSRect(x: 0, y: 1, width: bounds.width, height: 0.5)
        shadowLine.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
        highlightLine.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        highlightLine.backgroundColor = NSColor.white.withAlphaComponent(0.8).cgColor
    }
}
```

---

## 五、开发过程中的坑与解决方案

### 5.1 黑边 Bug（最棘手的问题）

#### 问题现象

卡片初始显示时有黑色细边框，鼠标悬停后再移开，黑边消失。

#### 根本原因

`borderWidth` 设置不一致：
- `init` 中设置 `borderWidth = 0.5`
- `mouseEntered` 中设置 `borderWidth = 0`
- `mouseExited` 中设置 `borderWidth = 0.5`
- `updateLayerContentsScale` 中又根据屏幕 scale 设置

多个地方修改 `borderWidth`，导致状态不一致。

#### 解决方案

**完全移除 border**，所有地方都设置 `borderWidth = 0`，只用 `shadow` 实现立体感。

```swift
// init 中
layer?.borderWidth = 0  // 完全移除边框

// updateLayerContentsScale 中
layer?.borderWidth = 0  // 移除 borderWidth 和 borderColor 设置

// mouseExited 中
layer?.borderWidth = 0  // 移除 borderWidth = 0.5
```

#### 经验教训

1. **不要用 border 实现 UI 效果**：CALayer 的 border 在 Retina/非 Retina 屏幕上表现不一致，容易出现1像素黑边
2. **用 shadow 替代 border**：shadow 更灵活，可控制颜色、模糊、偏移，且不会有像素对齐问题
3. **状态一致性**：同一个属性不要在多个地方修改，确保初始状态和各种交互后的状态一致

### 5.2 字体模糊问题

#### 问题现象

在 27 寸非 Retina 扩展屏上，卡片内的字体模糊，但在主屏 Retina 上清晰。不同窗口大小下模糊程度也不同。

#### 根本原因

1. **半透明背景导致的 alpha 合成**：卡片背景使用半透明颜色，与毛玻璃背景混合时，字体渲染会出现亚像素抗锯齿失效
2. **frame 非像素对齐**：卡片的 x/y/width/height 不是整数，导致字体渲染在亚像素位置
3. **contentsScale 未同步**：自定义 CALayer 的 contentsScale 没有根据屏幕 scale 更新

#### 解决方案

1. **卡片背景用不透明颜色**：`NSColor(white: 0.98, alpha: 1.0)`，避免半透明合成
2. **所有 frame 取整对齐像素网格**：
   ```swift
   private func alignSubviewsToPixels(_ view: NSView) {
       for sub in view.subviews {
           var f = sub.frame
           f.origin.x = round(f.origin.x)
           f.origin.y = round(f.origin.y)
           f.size.width = round(f.size.width)
           f.size.height = round(f.size.height)
           sub.frame = f
           alignSubviewsToPixels(sub)
       }
   }
   ```
3. **监听屏幕变化，同步 contentsScale**：
   ```swift
   override func viewDidChangeBackingProperties() {
       super.viewDidChangeBackingProperties()
       updateLayerContentsScale()
   }

   private func updateLayerContentsScale() {
       guard let scale = window?.backingScaleFactor else { return }
       layer?.contentsScale = scale
       gradientLayer?.contentsScale = scale
       // ...所有自定义 layer 都要同步
   }
   ```

#### 经验教训

1. **非 Retina 屏是字体渲染的试金石**：Retina 屏上像素密度高，轻微模糊看不出来；非 Retina 屏上任何亚像素偏移都会明显模糊
2. **避免半透明背景**：在毛玻璃窗口上，子视图尽量用不透明背景，避免 alpha 合成导致的字体渲染问题
3. **frame 必须像素对齐**：所有视图的 frame 都要取整，特别是动态计算的布局

### 5.3 滚轮滑动点亮多个卡片 Bug

#### 问题现象

鼠标在卡片区域快速滚动滚轮，会点亮多个卡片的悬停效果，且移开鼠标后无法熄灭。

#### 根本原因

`NSTrackingArea` 的 `mouseEntered`/`mouseExited` 事件在快速滚动时可能丢失。Timer 默认添加到 default runloop mode，滚轮滚动时 runloop 切换到 event tracking mode，Timer 不触发。

#### 解决方案

1. **添加全局鼠标移动监听**：
   ```swift
   NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel]) { _ in
       self.updateAllCardHoverStates()
       return event
   }
   ```
2. **定期更新悬停状态（80ms Timer）**，必须添加到 **common runloop mode**：
   ```swift
   hoverUpdateTimer = Timer(timeInterval: 0.08, repeats: true) { _ in
       self.updateAllCardHoverStates()
   }
   RunLoop.main.add(timer, forMode: .common)  // 关键：common mode
   ```
3. **监听滚动视图内容偏移变化**：
   ```swift
   scroll.contentView.postsBoundsChangedNotifications = true
   NotificationCenter.default.addObserver(
       forName: NSView.boundsDidChangeNotification,
       object: scroll.contentView, queue: .main
   ) { _ in self.updateAllCardHoverStates() }
   ```
4. **卡片提供 `applyHoverState(_:)` 公开方法**，允许外部强制设置状态，并用 `isHovered` 状态变量避免重复触发动画。

#### 经验教训

1. **NSTrackingArea 不可靠**：在快速滚动、窗口大小变化等场景下，mouseExited 事件可能丢失
2. **Timer 必须用 common mode**：否则滚轮滚动时（event tracking mode）Timer 不触发
3. **多重保险**：全局监听 + Timer + 滚动通知，三重确保悬停状态正确
4. **提供强制重置方法**：卡片组件应该提供 `applyHoverState(_:)` 公开方法

### 5.4 窗口大小变化后排版混乱

#### 问题现象

窗口放大或缩小后，卡片大小、字体大小、间距不协调，甚至出现重叠或截断。

#### 根本原因

1. NSStackView fillEqually 与手动约束冲突
2. intrinsicContentSize 依赖 bounds.width 导致循环依赖
3. 没有考虑最小/最大窗口尺寸的边界情况

#### 解决方案

1. **窗口宽度固定**：`minSize.width = maxSize.width = 480`，只允许纵向拉升
2. **自定义视图手动 layout**：`ComponentGridView` 完全手动计算 frame，避免 Auto Layout 冲突
3. **卡片大小根据宽度动态计算**：
   ```swift
   private func cardWidth(for width: CGFloat) -> CGFloat {
       max((width - CGFloat(cols - 1) * spacing) / CGFloat(cols), 80)
   }
   ```
4. **字体大小只缩小不放大**：根据内容长度动态缩小字体，确保不截断
   ```swift
   if enName.count > 40 || cnName.count > 10 {
       keycapSize -= 2; nameSize -= 2; enSize -= 1
   }
   ```

#### 经验教训

1. **固定宽度是简化布局的有效手段**：对于工具类应用，固定宽度可以大幅降低布局复杂度
2. **手动 layout 比 Auto Layout 更可控**：复杂网格布局用手动 frame 计算，避免约束冲突
3. **纵向拉升比横向拉升更安全**：纵向拉升只会增加行间距，不会影响卡片宽度和排版

### 5.5 死代码陷阱

#### 问题现象

修改了一个方法的代码，但运行后界面没有任何变化。

#### 根本原因

修改的方法是**死代码**，没有任何入口调用它。

#### 真实案例

曾创建 `showNotesPage()` 方法用于显示特别注意事项独立页面，但忘记添加调用入口。修改了这个方法几十次，界面始终没有变化。最后发现这个方法从未被调用过。

#### 解决方案（已在 V0.2 重构中清理）

在 V0.2 架构重构中，系统清理了以下死代码：
- `steppedSize()` / `roundToEven()` — 从未调用
- `VersionBadge` 类 — 版本功能已移除
- `ShortcutCardView` 类 — 已被 ComponentCardView 替代
- `makeGrid()` / `searchText(of:)` — 从未调用
- `showNotesPage()` / `backToDetail()` — 从未调用
- `homeSearchChanged()` — 首页无搜索框
- `ShortcutItem.version` / `helpUrl` — 从未使用

#### 预防措施

1. **添加代码前先确认调用入口**：新方法创建后立即添加调用，不要等"写完再连"
2. **用全局搜索确认调用关系**：`grep -n "方法名"` 确认有除定义外的其他引用
3. **定期清理死代码**：重构时删除未使用的方法、变量、类，避免混淆

---

## 六、UI/UX 设计原则

### 6.1 立体感设计

#### 阴影层次

- **卡片外阴影**：`shadowOffset = (0, -6)`，`shadowRadius = 16`，`shadowOpacity = 0.30`，模拟卡片浮在背景上
- **键帽外阴影**：`shadowOffset = (0, -1)`，`shadowRadius = 2`，`shadowOpacity = 0.18`，模拟键帽浮在卡片上
- **悬停上浮**：`layer.transform = CATransform3DMakeTranslation(0, 8, 0)`，SPICE 指令卡片悬停时上浮8pt

#### 渐变背景

- **卡片渐变**：顶部 `white: 0.98`，底部 `white: 0.91`，明显渐变增加质感
- **键帽渐变**：顶部 `white: 0.97`，底部 `white: 0.86`，明显渐变模拟凸起
- **渐变方向**：`startPoint = (0,0)`，`endPoint = (0,1)`，从上到下（模拟光源从上方照射）

### 6.2 交互反馈

#### 鼠标悬停

- **手型光标**：可点击元素（SPICE 指令卡片、首页卡片、按钮、tab）使用 `NSCursor.pointingHand`
- **上浮动画**：`CATransform3DMakeTranslation(0, 6~8, 0)`，0.15~0.3秒缓动
- **背景变亮**：渐变颜色整体提亮
- **彩虹发光**：首页卡片悬停时背面散发出彩虹光晕 + 呼吸脉冲
- **描边发光**：SPICE 指令卡片悬停时蓝色描边 + 外圈光晕

#### 点击反馈

- **按下下沉**：`frame.offsetBy(dx: 0, dy: 1)`，0.08秒
- **释放回弹**：`frame.offsetBy(dx: 0, dy: -1)`，0.12秒

### 6.3 字体规范

| 元素 | 字体 | 字号 | 字重 | 颜色 |
|------|------|------|------|------|
| 软件名（首页/详情） | Impact | 16-20pt | heavy | labelColor |
| 键帽文字 | 系统字体 | 14-15pt | semibold | labelColor |
| 功能中文名 | 系统字体 | 12-13pt | semibold | labelColor |
| 英文描述 | 系统字体 | 11pt | regular | secondaryLabelColor |
| 版本信息 | 系统字体 | 11pt | regular | tertiaryLabelColor |
| tab 按钮 | 系统字体 | 12pt | medium | secondaryLabelColor |
| tab 选中 | 系统字体 | 12pt | bold | white（蓝色背景） |
| 注意事项正文 | 系统字体 | 13.5pt | regular | labelColor |

**字体选择原则**：
- 标题用 Impact 字体增加艺术感和辨识度
- 正文用系统字体确保可读性和一致性
- 重要信息用 semibold/bold，次要信息用 regular
- 颜色层级：labelColor > secondaryLabelColor > tertiaryLabelColor

---

## 七、编译与部署

### 7.1 编译脚本

项目提供 `build.sh` 一键编译脚本（Nexus 标准构建脚本）：

```bash
cd /path/to/KeyHub
./build.sh              # 编译 + 同步资源 + 签名
./build.sh --no-sign    # 只编译不签名
./build.sh --clean      # 清理后重新编译
```

脚本自动完成：
1. 收集 `Sources/` 下所有 `.swift` 文件（含 Common/ 共享代码）
2. 用 `swiftc` 编译，链接 Cocoa + Carbon 框架
3. 输出到 `KeyHub.app/Contents/MacOS/KeyHub`
4. 同步 `guides/` 到 app bundle 的 Resources 目录
5. ad-hoc 签名（`codesign --force --deep --sign -`）

#### 手动编译命令

```bash
swiftc Sources/**/*.swift Sources/main.swift \
    -o KeyHub.app/Contents/MacOS/KeyHub \
    -framework Cocoa \
    -framework Carbon \
    -O \
    -whole-module-optimization
```

#### 参数说明

- `-O`：优化编译（Release 级别）
- `-whole-module-optimization`：全模块优化，提升编译后性能
- `-framework Cocoa`：链接 Cocoa 框架（UI 相关）
- `-framework Carbon`：链接 Carbon 框架（全局热键相关）

### 7.2 签名

```bash
codesign --force --deep --sign - KeyHub.app
```

- `--force`：强制覆盖已有签名
- `--deep`：递归签名所有嵌套内容
- `--sign -`：使用临时签名（ad-hoc），不需要开发者证书

### 7.3 运行

```bash
# 先杀掉已运行的进程
pkill -9 -f KeyHub

# 打开应用
open KeyHub.app
```

### 7.4 App Bundle 结构

```
KeyHub.app/
└── Contents/
    ├── Info.plist          # 应用配置
    ├── MacOS/
    │   └── KeyHub          # 可执行文件
    ├── Resources/
    │   ├── AppIcon.icns    # 应用图标
    │   ├── LTspice.png     # 软件图标
    │   └── guides/         # 快捷键数据（运行时加载）
    │       └── ltspice.md
    └── _CodeSignature/     # 代码签名
```

#### Info.plist 关键配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>KeyHub</string>
    <key>CFBundleDisplayName</key>
    <string>KeyHub</string>
    <key>CFBundleIdentifier</key>
    <string>com.nexus.tool.keyhub</string>
    <key>CFBundleVersion</key>
    <string>0.3.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.3.0</string>
    <key>CFBundleExecutable</key>
    <string>KeyHub</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.nexus.tool.keyhub</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>nexus-keyhub</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

---

## 八、后续扩展建议

### 8.1 新增软件指南

1. 在 `guides/` 目录下新增 `软件名.md` 文件，按约定格式编写快捷键数据
2. 将软件图标（`软件名.png`）放入 `KeyHub.app/Contents/Resources/`
3. 重新运行 `./build.sh`（会自动同步 guides 到 app bundle）
4. 应用启动时自动扫描 `guides/` 目录，首页自动显示新软件卡片

**无需修改任何 Swift 代码**，数据驱动设计。

### 8.2 功能扩展方向

- **快捷键点击复制**：点击快捷键卡片复制到剪贴板
- **最近使用/收藏**：常用快捷键收藏和快速访问
- **自定义快捷键导入**：读取 LTspice.ini 等配置文件
- **上下文感知**：检测当前活跃应用，自动切换到对应软件的快捷键指南
- **快捷键练习模式**：类似打字练习，帮助用户记忆快捷键
- **导出 PDF**：快捷键列表打印/导出
- **Windows 版本**：使用 WPF / WinUI 重写（数据格式已按跨平台设计）

### 8.3 架构演进方向

当前多文件架构已适合中小规模协作。项目进一步扩大后可考虑：

- **Xcode 项目**：当需要复杂构建配置、资源管理、测试目标时
- **Swift Package Manager**：将数据模型和解析器抽成独立库
- **MVVM 架构**：将 AppDelegate 中的页面逻辑拆分为 ViewModel
- **单元测试**：为 GuideParser 和数据模型添加测试

---

## 九、开发工具与工作流

### 9.1 推荐工具

- **编辑器**：VS Code + Swift 插件，或 Xcode（仅用于编辑，不用于编译）
- **调试**：`lldb` 命令行调试，或 Xcode 附加到进程
- **界面验证**：每次修改后必须重新编译运行，肉眼验证 UI 效果
- **截图工具**：`screencapture` 命令行，或系统截图快捷键

### 9.2 开发工作流

1. **修改代码**：在 `Sources/` 对应模块文件中修改
2. **编译**：`./build.sh` 编译，检查语法错误
3. **签名**：`codesign --force --deep --sign - KeyHub.app`
4. **重启应用**：`pkill -9 -f KeyHub && open KeyHub.app`
5. **验证**：肉眼验证 UI 效果，测试交互功能
6. **迭代**：如果不符合预期，回到步骤1
7. **记录**：重大变更更新 `CHANGELOG.md`

### 9.3 验证清单

每次修改后，至少验证以下内容：

- [ ] 应用能正常启动，无崩溃
- [ ] 全局热键 ⌃⌥L 能正常唤出/隐藏
- [ ] 首页卡片布局正常，无重叠/截断
- [ ] 点击卡片能进入详情页
- [ ] 详情页 tab 切换正常
- [ ] 搜索功能正常
- [ ] SPICE 指令点击弹出详细说明
- [ ] 卡片悬停效果正常（上浮、发光）
- [ ] 窗口纵向拉升后布局正常
- [ ] 菜单栏图标正常，菜单功能正常
- [ ] 字体清晰，无模糊（特别注意非 Retina 屏）
- [ ] 无黑边、无异常边框
- [ ] 滚轮滚动时卡片悬停状态正常

---

## 十、总结

### 10.1 核心经验

1. **模块化优先**：按职责拆分文件，多人协作冲突少，代码导航高效
2. **数据驱动**：所有快捷键内容来自 guides/*.md，新增软件零代码改动
3. **视觉一致性**：统一的阴影、渐变、字体规范，确保整体质感
4. **像素级对齐**：所有 frame 取整，contentsScale 同步，避免字体模糊
5. **状态一致性**：同一个属性不要在多个地方修改，避免黑边等状态不一致问题
6. **验证驱动**：每次修改后必须编译运行验证，不要凭想象判断效果

### 10.2 踩坑清单

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 卡片黑边 | borderWidth 多地方修改不一致 | 完全移除 border，用 shadow 替代 |
| 字体模糊 | 半透明背景 + frame 非像素对齐 | 不透明背景 + frame 取整 + contentsScale 同步 |
| 滚轮点亮多卡片 | mouseExited 事件丢失 + Timer mode 不对 | 全局监听 + common mode Timer + 滚动通知 三重保险 |
| 窗口拉伸排版乱 | Auto Layout 约束冲突 | 固定窗口宽度 + 自定义视图手动 layout |
| 死代码不生效 | 方法无调用入口 | 添加代码后立即确认调用关系，定期清理 |

### 10.3 给后续开发者的建议

1. **先读本文档再动手**：本文档记录了所有踩过的坑和解决方案，避免重复犯错
2. **小步快跑**：每次只改一个点，改完立即验证，不要一次性改太多
3. **保留验证习惯**：UI 开发必须肉眼验证，不要凭代码逻辑判断效果
4. **善用搜索**：遇到问题先在本文档和 ISSUES.md 中搜索，可能已经有解决方案
5. **持续更新文档**：遇到新问题和解决方案，及时补充到本文档中
6. **更新 CHANGELOG**：每次功能变更或重构，记录到 CHANGELOG.md

---

## 十一、Nexus 元宇宙接入

### 11.1 元宇宙身份

KeyHub 是 Nexus 软件元宇宙的**工具类**成员应用。

| 项 | 值 |
|----|----|
| 元宇宙版本 | Nexus 1.0 |
| 应用分类 | tool（工具类） |
| Bundle ID | `com.nexus.tool.keyhub` |
| URL Scheme | `nexus-keyhub://` |
| 配置文件 | `nexus.json` |
| 规范文档 | 单独保存（Nexus 文档中心） |

### 11.2 共享组件使用

KeyHub 引入了以下 Nexus CommonKit 共享组件（`Sources/Common/`）：

| 组件 | 用途 | 替代原有 |
|------|------|----------|
| `NXHotKeyManager` | 全局热键注册/注销 | 原 `HotKeyManager`（已删除） |
| `NXWindowStyle` | 毛玻璃浮动窗口创建 | （预留，当前仍用内联实现） |
| `NXStatusItem` | 菜单栏项和菜单模板 | （预留） |
| `NXPixelUtils` | 像素对齐工具 | （预留） |
| `NXCommon` | 元宇宙元信息、应用分类 | 新增 |

### 11.3 跨应用唤起

KeyHub 注册了 URL Scheme `nexus-keyhub://`，其他 Nexus 应用可通过：

```swift
NSWorkspace.shared.open(URL(string: "nexus-keyhub://")!)
```

唤起 KeyHub。未来可扩展 `nexus-keyhub://search?q=xxx` 等深度链接。

### 11.4 新应用接入

创建新的 Nexus 应用时：
1. 参考 Nexus 文档中心的规范
2. 复制项目结构模板
3. 按需引入 `Sources/Common/` 共享组件
4. 填写 `nexus.json`
5. 注册 `nexus-<标识>` URL Scheme

---

*文档结束 · KeyHub V0.3 · 2026-08-26*

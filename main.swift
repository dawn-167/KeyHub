import Cocoa
import Carbon.HIToolbox

// MARK: - 辅助函数

/// 阶梯式字体大小：只在固定值间跳变，避免非Retina屏连续字号渲染模糊
private func steppedSize(_ w: CGFloat, _ minSize: CGFloat, _ maxSize: CGFloat) -> CGFloat {
    let step: CGFloat = 4  // 每4pt跳一档，档位少渲染稳定
    let ratio = max(0, min(1, (w - 100) / 200))
    let continuous = minSize + ratio * (maxSize - minSize)
    let stepped = floor(continuous / step) * step
    return max(minSize, min(maxSize, stepped))
}

/// 取整到最近的偶数，避免非Retina屏子像素渲染模糊
private func roundToEven(_ value: CGFloat) -> CGFloat {
    let rounded = round(value)
    return rounded.truncatingRemainder(dividingBy: 2) == 0 ? rounded : rounded + 1
}

// MARK: - 全局热键（⌃⌥L）

private let kHotKeyCode: UInt32 = UInt32(kVK_ANSI_L)
private let kHotKeyModifiers: UInt32 = UInt32(controlKey) | UInt32(optionKey)
private var hotKeyRef: EventHotKeyRef?
private weak var appDelegateRef: AppDelegate?

private func hotKeyHandler(_ nextHandler: EventHandlerCallRef?,
                           _ theEvent: EventRef?,
                           _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async { appDelegateRef?.toggleWindow() }
    return noErr
}

// MARK: - 数据模型

struct ShortcutItem {
    let combos: [[String]]
    let desc: String
    let version: String   // 适用版本标注，如 "[24+]"、"[XVII]"，空字符串表示全版本通用
    var detail: String = ""  // 详细使用说明
    var helpUrl: String = "" // 官方帮助文档链接
}

struct SectionData {
    let title: String
    var items: [ShortcutItem] = []
    var notes: [String] = []
}

struct SoftwareGuide {
    let name: String
    let version: String
    let icon: String
    let lastUpdated: String
    let minVersion: String
    let sections: [SectionData]
    var totalShortcuts: Int { sections.reduce(0) { $0 + $1.items.count } }
}

// MARK: - 指南解析

enum GuideParser {
    static func load(from text: String) -> SoftwareGuide {
        var name = "未知软件"
        var version = "—"
        var icon = "command"
        var lastUpdated = "—"
        var minVersion = "—"
        var sections: [SectionData] = []
        var current: SectionData?
        var inFrontmatter = false
        var frontmatterDone = false
        var currentDetailItem: Int? = nil
        var inOptionsTable = false

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)

            // 解析 YAML frontmatter
            if line == "---" {
                if !frontmatterDone {
                    inFrontmatter.toggle()
                    if !inFrontmatter { frontmatterDone = true }
                }
                continue
            }
            if inFrontmatter {
                if let colonRange = line.range(of: ":") {
                    let key = String(line[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let value = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    switch key.lowercased() {
                    case "name": name = value
                    case "version": version = value
                    case "icon": icon = value
                    case "last_updated": lastUpdated = value
                    case "min_version": minVersion = value
                    default: break
                    }
                }
                continue
            }

            if line.isEmpty || line == "---" { continue }

            if line.hasPrefix("## ") {
                if let cur = current { sections.append(cur) }
                current = SectionData(title: String(line.dropFirst(3)))
                currentDetailItem = nil
                inOptionsTable = false
                continue
            }
            if line.hasPrefix("# ") {
                let t = String(line.dropFirst(2))
                if t.contains("注意") || t.contains("说明") {
                    if let cur = current { sections.append(cur) }
                    current = SectionData(title: t)
                    currentDetailItem = nil
                    inOptionsTable = false
                }
                continue
            }
            if line.hasPrefix("> ") {
                let t = strip(String(line.dropFirst(2)))
                current?.notes.append(t)
                continue
            }
            if line.hasPrefix("#### ") {
                // 指令详细说明子标题，如 "#### .TRAN — 瞬态分析"
                let title = String(line.dropFirst(5))
                if title.hasPrefix(".") {
                    // 提取指令名
                    let cmdName = title.components(separatedBy: " ")[0].components(separatedBy: "—")[0].trimmingCharacters(in: .whitespaces)
                    // 在当前 section 中查找匹配的 item
                    if let idx = current?.items.firstIndex(where: { $0.combos.first?.first == cmdName }) {
                        current?.items[idx].detail = ""
                        currentDetailItem = idx
                    }
                }
                continue
            }
            if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
                currentDetailItem = nil
            }
            if currentDetailItem != nil && !line.hasPrefix("|") && !line.hasPrefix("```") {
                // 累积详细说明文本，空行作为段落分隔
                if line.isEmpty {
                    if let cur = current, !cur.items[currentDetailItem!].detail.isEmpty {
                        var newCur = cur
                        newCur.items[currentDetailItem!].detail += "\n\n"
                        current = newCur
                    }
                } else {
                    let t = strip(line)
                    if !t.isEmpty, var cur = current {
                        let idx = currentDetailItem!
                        cur.items[idx].detail += (cur.items[idx].detail.isEmpty ? "" : "\n") + t
                        current = cur
                    }
                }
                continue
            }
            if line.hasPrefix("|") {
                guard let cells = tableCells(line), cells.count >= 2 else { continue }
                let keyCell = cells[0]
                // 跳过表头和分隔行
                if keyCell == "快捷键" || keyCell == "版本" || keyCell == "指令" || keyCell == "参数" ||
                    keyCell.allSatisfy({ $0 == "-" || $0 == ":" }) {
                    if keyCell == "参数" { inOptionsTable = true }
                    continue
                }
                if inOptionsTable { continue }  // 跳过 .OPTIONS 参数表
                let combos = parseCombo(keyCell)
                if combos.isEmpty { continue }
                var desc = cells[1].replacingOccurrences(of: "**", with: "")
                var version = ""
                if cells.count >= 3 {
                    let third = cells[2].replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                    // 判断第三列是版本标注还是其他内容（如语法、默认值）
                    if third == "全版本" || third.hasPrefix("[") || third.isEmpty {
                        version = third
                    } else {
                        // 合并到功能描述，去除反引号
                        let cleanThird = third.replacingOccurrences(of: "`", with: "")
                        desc = "\(desc)（\(cleanThird)）"
                    }
                }
                current?.items.append(ShortcutItem(combos: combos, desc: desc, version: version))
                continue
            }
            inOptionsTable = false  // 非表格行，重置参数表标记
            if let num = line.first, num.isNumber, line.contains(". ") {
                let parts = line.split(separator: ".", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    current?.notes.append(strip(parts[1].trimmingCharacters(in: .whitespaces)))
                }
                continue
            }
        }
        if let cur = current { sections.append(cur) }
        return SoftwareGuide(name: name, version: version, icon: icon,
                             lastUpdated: lastUpdated, minVersion: minVersion, sections: sections)
    }

    private static func tableCells(_ line: String) -> [String]? {
        var cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.first == "" { cells.removeFirst() }
        if cells.last == "" { cells.removeLast() }
        return cells.isEmpty ? nil : cells
    }

    private static func parseCombo(_ cell: String) -> [[String]] {
        let stripped = cell.replacingOccurrences(of: "**", with: "")
        let noAnno = stripped.replacingOccurrences(of: "（[^）]*）", with: "", options: .regularExpression)
        var result: [[String]] = []
        for part in noAnno.components(separatedBy: "/") {
            let keys = part.components(separatedBy: "+")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !keys.isEmpty { result.append(keys) }
        }
        return result
    }

    private static func strip(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
    }
}

// MARK: - 键帽视图（显示官方键名，不做 Mac 符号转换）

final class KeycapView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var currentFontSize: CGFloat = 15
    private var gradientLayer: CAGradientLayer!
    private var topHighlight: CALayer!
    private var bottomShadow: CALayer!

    init(key: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        layer?.masksToBounds = false
        // 外阴影：轻微投影，增加立体感
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        layer?.shadowRadius = 2
        layer?.shadowOpacity = 1

        // 渐变背景：顶亮底暗，模拟凸起
        let grad = CAGradientLayer()
        grad.cornerRadius = 6
        grad.colors = [
            NSColor(white: 0.97, alpha: 1.0).cgColor,
            NSColor(white: 0.86, alpha: 1.0).cgColor
        ]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint = CGPoint(x: 0, y: 1)
        layer?.insertSublayer(grad, at: 0)
        gradientLayer = grad

        // 顶部高光线：1px 白色半透明
        let top = CALayer()
        top.backgroundColor = NSColor.white.withAlphaComponent(0.65).cgColor
        top.cornerRadius = 6
        top.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer?.insertSublayer(top, above: grad)
        topHighlight = top

        // 底部阴影线：1px 深灰半透明
        let bottom = CALayer()
        bottom.backgroundColor = NSColor.black.withAlphaComponent(0.10).cgColor
        bottom.cornerRadius = 6
        bottom.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        layer?.insertSublayer(bottom, above: grad)
        bottomShadow = bottom

        label.stringValue = key
        label.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -0.5),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
        ])
    }

    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
        // 顶部高光线：高度1px，在顶部
        topHighlight?.frame = NSRect(x: 0.5, y: bounds.height - 1.5, width: bounds.width - 1, height: 1.5)
        // 底部阴影线：高度1px，在底部
        bottomShadow?.frame = NSRect(x: 0.5, y: 0, width: bounds.width - 1, height: 1.5)
    }

    func setFontSize(_ size: CGFloat) {
        currentFontSize = size
        label.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        invalidateIntrinsicContentSize()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize {
        let font = NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
        let w = (label.stringValue as NSString).size(withAttributes: [.font: font]).width
        let h = max(22, currentFontSize * 1.7)
        return NSSize(width: max(ceil(w) + 14, 28), height: h)
    }
}

// MARK: - 版本徽标

final class VersionBadge: NSTextField {
    init(text: String) {
        super.init(frame: .zero)
        stringValue = text
        font = NSFont.systemFont(ofSize: 9.5, weight: .semibold)
        textColor = .white
        alignment = .center
        drawsBackground = true
        isBezeled = false
        isEditable = false
        isSelectable = false
        backgroundColor = text.contains("XVII") ? .systemOrange :
                          text.contains("24") ? .systemBlue : .systemGray
        // 圆角
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 快捷键卡片

final class ShortcutCardView: NSView {
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?

    init(item: ShortcutItem) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = false
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.1).cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        layer?.shadowRadius = 4
        layer?.shadowOpacity = 1

        // 渐变背景
        let grad = CAGradientLayer()
        grad.cornerRadius = 10
        grad.colors = [
            NSColor.controlBackgroundColor.withAlphaComponent(0.7).cgColor,
            NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        ]
        grad.locations = [0, 1]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint = CGPoint(x: 0, y: 1)
        layer?.insertSublayer(grad, at: 0)
        gradientLayer = grad

        let keyRow = NSStackView()
        keyRow.orientation = .horizontal
        keyRow.alignment = .centerY
        keyRow.spacing = 3
        keyRow.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        keyRow.setContentCompressionResistancePriority(.required, for: .horizontal)
        keyRow.translatesAutoresizingMaskIntoConstraints = false

        for (ci, combo) in item.combos.enumerated() {
            if ci > 0 {
                let slash = NSTextField(labelWithString: "/")
                slash.font = NSFont.systemFont(ofSize: 10, weight: .medium)
                slash.textColor = .tertiaryLabelColor
                keyRow.addArrangedSubview(slash)
            }
            for (ki, key) in combo.enumerated() {
                if ki > 0 {
                    let plus = NSTextField(labelWithString: "+")
                    plus.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
                    plus.textColor = .tertiaryLabelColor
                    keyRow.addArrangedSubview(plus)
                }
                keyRow.addArrangedSubview(KeycapView(key: key))
            }
        }

        // 描述（移除版本徽标）
        let desc = NSTextField(wrappingLabelWithString: item.desc)
        desc.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        desc.textColor = .labelColor
        desc.lineBreakMode = .byWordWrapping
        desc.maximumNumberOfLines = 0
        desc.setContentHuggingPriority(.defaultLow, for: .horizontal)
        desc.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        desc.translatesAutoresizingMaskIntoConstraints = false

        let hStack = NSStackView(views: [keyRow, desc])
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 10
        hStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // 悬停效果
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        if let ta = trackingArea { addTrackingArea(ta) }
    }

    override func mouseEntered(with event: NSEvent) {
        gradientLayer?.colors = [
            NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor,
            NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
        ]
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
        layer?.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        layer?.shadowRadius = 8
        layer?.shadowOffset = NSSize(width: 0, height: -2)
    }

    override func mouseExited(with event: NSEvent) {
        gradientLayer?.colors = [
            NSColor.controlBackgroundColor.withAlphaComponent(0.7).cgColor,
            NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        ]
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.1).cgColor
        layer?.shadowRadius = 4
        layer?.shadowOffset = NSSize(width: 0, height: -1)
    }
}

// MARK: - 提示气泡

final class CalloutView: NSView {
    enum Kind { case warning, info, note }
    private let label: NSTextField
    private var lastWidth: CGFloat = 0

    init(text: String, kind: Kind = .note) {
        label = NSTextField(wrappingLabelWithString: text)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 0.5

        let accent: NSColor
        switch kind {
        case .warning: accent = .systemOrange
        case .info:    accent = .systemBlue
        case .note:    accent = .systemGray
        }
        layer?.borderColor = accent.withAlphaComponent(0.22).cgColor
        layer?.backgroundColor = accent.withAlphaComponent(0.07).cgColor

        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = accent.cgColor
        bar.layer?.cornerRadius = 1.5
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)

        label.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            bar.widthAnchor.constraint(equalToConstant: 3),
            label.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        if w > 0 && abs(w - lastWidth) > 1 {
            lastWidth = w
            // 字体随宽度动态缩放（基准宽度600pt，基准字号11.5pt）
            let fontSize = max(10, min(16, w * 0.019))
            label.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 透传点击的 Label（不拦截鼠标事件）

final class ClickThroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - 手型光标按钮

final class HandCursorButton: NSButton {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - 分区标签（多行换行，手型光标）

final class SectionTabView: NSView {
    private var buttons: [NSButton] = []
    var onSelect: ((Int) -> Void)?
    var alwaysHighlightTitles: Set<String> = []
    var selectedIndex: Int = 0 {
        didSet { updateSelection() }
    }

    override var isFlipped: Bool { true }

    func configure(titles: [String]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        for (i, title) in titles.enumerated() {
            let btn = NSButton(title: title, target: self, action: #selector(tabClicked(_:)))
            btn.tag = i
            btn.bezelStyle = .inline
            btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            btn.translatesAutoresizingMaskIntoConstraints = false
            addSubview(btn)
            buttons.append(btn)
        }
        updateSelection()
        needsLayout = true
    }

    @objc private func tabClicked(_ sender: NSButton) {
        selectedIndex = sender.tag
        updateSelection()
        onSelect?(sender.tag)
    }

    func updateSelection() {
        for (i, btn) in buttons.enumerated() {
            let isSelected = i == selectedIndex
            let isAlwaysHighlight = alwaysHighlightTitles.contains(btn.title)
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 6
            btn.layer?.masksToBounds = false
            if isSelected {
                // 选中标签：蓝色背景+白色文字+发光
                btn.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor
                btn.contentTintColor = .white
                btn.font = NSFont.systemFont(ofSize: 12, weight: .bold)
                btn.layer?.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
                btn.layer?.shadowRadius = 8
                btn.layer?.shadowOffset = NSSize(width: 0, height: 0)
                btn.layer?.shadowOpacity = 0.6
            } else if isAlwaysHighlight {
                // 常亮标签：蓝色加粗文字，无背景
                btn.layer?.backgroundColor = NSColor.clear.cgColor
                btn.contentTintColor = .controlAccentColor
                btn.font = NSFont.systemFont(ofSize: 12, weight: .bold)
                btn.layer?.shadowColor = NSColor.clear.cgColor
                btn.layer?.shadowOpacity = 0
            } else {
                // 未选中标签：灰色文字
                btn.layer?.backgroundColor = NSColor.clear.cgColor
                btn.contentTintColor = .secondaryLabelColor
                btn.font = NSFont.systemFont(ofSize: 12, weight: .regular)
                btn.layer?.shadowColor = NSColor.clear.cgColor
                btn.layer?.shadowOpacity = 0
            }
        }
    }

    override func layout() {
        super.layout()
        let padding: CGFloat = 6
        let spacing: CGFloat = 4
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = bounds.width

        for btn in buttons {
            let size = btn.intrinsicContentSize
            let btnWidth = size.width + padding * 2
            let btnHeight = size.height + padding

            if x + btnWidth > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            btn.frame = NSRect(x: x, y: y, width: btnWidth, height: btnHeight)
            x += btnWidth + spacing
            rowHeight = max(rowHeight, btnHeight)
        }
        calculatedHeight = y + rowHeight
        invalidateIntrinsicContentSize()
    }

    private var calculatedHeight: CGFloat = 28

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: calculatedHeight)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for btn in buttons {
            addCursorRect(btn.frame, cursor: .pointingHand)
        }
    }
}

// MARK: - 元件卡片（放置元件专用，方形大卡片，3列网格）

final class ComponentCardView: NSView {
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var highlightLayer: CALayer?
    private var bottomShadowLayer: CALayer?
    private let keyRow = NSStackView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let enLabel = NSTextField(labelWithString: "")
    private let isCommand: Bool
    private var isHovered = false
    private var glowLayers: [CALayer] = []
    var onClick: (() -> Void)?
    let item: ShortcutItem

    init(item: ShortcutItem) {
        self.item = item
        isCommand = item.combos.first?.first?.hasPrefix(".") == true
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = false
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.30).cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -6)
        layer?.shadowRadius = 16
        layer?.shadowOpacity = 1

        // 点击手势
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)

        // 渐变背景（不透明，顶亮底暗柔和过渡，避免整页上亮下暗）
        let grad = CAGradientLayer()
        grad.cornerRadius = 14
        let cardBg = NSColor(white: 0.98, alpha: 1.0)
        let cardBg2 = NSColor(white: 0.91, alpha: 1.0)
        grad.colors = [cardBg.cgColor, cardBg2.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint = CGPoint(x: 0, y: 1)
        layer?.insertSublayer(grad, at: 0)
        gradientLayer = grad

        // 顶部高光线（增强立体感，更明显）
        let hl = CALayer()
        hl.backgroundColor = NSColor.white.withAlphaComponent(0.65).cgColor
        hl.cornerRadius = 14
        hl.masksToBounds = true
        layer?.insertSublayer(hl, above: grad)
        highlightLayer = hl

        // 底部阴影线（增强立体感，更明显）
        let bs = CALayer()
        bs.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        bs.cornerRadius = 14
        bs.masksToBounds = true
        layer?.insertSublayer(bs, above: grad)
        bottomShadowLayer = bs

        // SPICE指令描边发光层
        let glowConfigs: [(inset: CGFloat, width: CGFloat, alpha: CGFloat)] = [
            (inset: -1,  width: 0.6, alpha: 0.90),
            (inset: -4,  width: 3,   alpha: 0.15),
        ]
        for cfg in glowConfigs {
            let glow = CALayer()
            glow.frame = bounds.insetBy(dx: cfg.inset, dy: cfg.inset)
            glow.cornerRadius = 14 - cfg.inset
            glow.borderWidth = cfg.width
            glow.borderColor = NSColor.controlAccentColor.withAlphaComponent(cfg.alpha).cgColor
            glow.opacity = 0
            layer?.insertSublayer(glow, at: 1)
            glowLayers.append(glow)
        }

        // 解析功能描述：中文名（英文名）
        // 注意：SPICE指令可能有两个括号，如"小信号交流分析（频响）（.AC dec 100 1Hz 100MEG）"
        // 用lastIndex取最后一个括号作为enName（语法示例）
        let desc = item.desc
        var cnName = desc
        var enName = ""
        if let lp = desc.lastIndex(of: "（"), let rp = desc.lastIndex(of: "）"), lp < rp {
            cnName = String(desc[..<lp]).trimmingCharacters(in: .whitespaces)
            enName = String(desc[desc.index(after: lp)..<rp]).trimmingCharacters(in: .whitespaces)
        }

        // 动态字体大小：字少的放大，字多的保持，特别长的缩小（确保显示全）
        let comboCount = item.combos.first?.count ?? 0
        let baseKeycap: CGFloat = isCommand ? 16 : 20
        let baseName: CGFloat = isCommand ? 14 : 18
        let baseEn: CGFloat = isCommand ? 12 : 14
        let basePlus: CGFloat = isCommand ? 12 : 16
        var keycapSize = baseKeycap
        var nameSize = baseName
        var enSize = baseEn
        var plusSize = basePlus
        // 根据内容长度调整字体（组合键>=2的不放大，只缩小，确保键帽不被截断）
        if comboCount < 2 && cnName.count <= 2 && comboCount <= 1 && enName.count <= 10 {
            // 很短，放大2号
            keycapSize += 4
            nameSize += 4
            enSize += 2
            plusSize += 2
        } else if comboCount < 2 && cnName.count <= 4 && comboCount <= 2 && enName.count <= 20 {
            // 中等，放大1号
            keycapSize += 2
            nameSize += 2
            enSize += 1
            plusSize += 1
        } else if enName.count > 40 || cnName.count > 10 {
            // 特别长，缩小2号确保显示全
            keycapSize -= 2
            nameSize -= 2
            enSize -= 1
            plusSize -= 1
        } else if enName.count > 10 || cnName.count > 8 {
            // 较长（11-40字符），缩小1号确保在正方形中显示全
            keycapSize -= 1
            nameSize -= 1
            enSize -= 1
            plusSize -= 1
        }

        // 组合键多的，额外缩小键帽字体确保不被截断
        if comboCount >= 3 {
            keycapSize -= 3
            plusSize -= 2
        } else if comboCount >= 2 {
            keycapSize -= 2
            plusSize -= 1
        }
        // 确保键帽字体不小于10
        keycapSize = max(keycapSize, 10)
        plusSize = max(plusSize, 10)

        // 键帽（支持组合键，多个键帽并排）
        keyRow.orientation = .horizontal
        keyRow.alignment = .centerY
        keyRow.spacing = 2
        keyRow.translatesAutoresizingMaskIntoConstraints = false
        if let combo = item.combos.first {
            for (ki, key) in combo.enumerated() {
                if ki > 0 {
                    let plus = NSTextField(labelWithString: "+")
                    plus.font = NSFont.systemFont(ofSize: plusSize, weight: .semibold)
                    plus.textColor = .secondaryLabelColor
                    plus.isBezeled = false
                    plus.isBordered = false
                    plus.drawsBackground = false
                    keyRow.addArrangedSubview(plus)
                }
                let keycap = KeycapView(key: key)
                keycap.translatesAutoresizingMaskIntoConstraints = false
                keycap.setFontSize(keycapSize)
                keyRow.addArrangedSubview(keycap)
            }
        }

        // 功能名
        nameLabel.stringValue = cnName
        nameLabel.font = NSFont.systemFont(ofSize: nameSize, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 3
        nameLabel.isBezeled = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // 英文名（可选）
        enLabel.stringValue = enName
        enLabel.font = NSFont.systemFont(ofSize: enSize, weight: .regular)
        enLabel.textColor = .secondaryLabelColor
        enLabel.alignment = .center
        enLabel.lineBreakMode = .byTruncatingTail
        enLabel.maximumNumberOfLines = 5
        enLabel.isHidden = enName.isEmpty
        enLabel.isBezeled = false
        enLabel.isBordered = false
        enLabel.drawsBackground = false
        enLabel.translatesAutoresizingMaskIntoConstraints = true

        // 手动布局：确保所有元素位置都是整数像素，避免子像素渲染模糊
        addSubview(keyRow)
        addSubview(nameLabel)
        addSubview(enLabel)
    }

    override func layout() {
        super.layout()
        updateLayerContentsScale()
        gradientLayer?.frame = bounds
        // 顶部高光线：1.5px，在顶部
        highlightLayer?.frame = NSRect(x: 0.5, y: bounds.height - 2, width: bounds.width - 1, height: 2)
        // 底部阴影线：1.5px，在底部
        bottomShadowLayer?.frame = NSRect(x: 0.5, y: 0, width: bounds.width - 1, height: 2)
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: 14, cornerHeight: 14, transform: nil)
        // 辉光层跟随卡片尺寸
        let baseWidth: CGFloat = 200
        let scale = max(0.5, min(2.0, bounds.width / baseWidth))
        let glowWidths: [CGFloat] = [0.6 * scale, 3 * scale]
        let glowInsets: [CGFloat] = [-1 * scale, -4 * scale]
        for (i, glow) in glowLayers.enumerated() where i < glowInsets.count {
            let inset = glowInsets[i]
            glow.frame = bounds.insetBy(dx: inset, dy: inset)
            glow.cornerRadius = 14 - inset
            glow.borderWidth = glowWidths[i]
        }
        // 字体大小固定（27寸副屏最清晰的大小），不随卡片大小变化
        // 手动布局：确保每个元素位置都是整数像素，避免子像素渲染模糊
        let cardW = bounds.width
        let cardH = bounds.height
        let spacing: CGFloat = 10
        // 计算各元素大小（取整）
        keyRow.layoutSubtreeIfNeeded()
        let keyRowSize = keyRow.fittingSize
        let keyRowW = round(min(keyRowSize.width, cardW - 24))
        let keyRowH = round(keyRowSize.height)
        let nameSize = nameLabel.sizeThatFits(NSSize(width: cardW - 24, height: .greatestFiniteMagnitude))
        let nameW = cardW - 24
        let nameH = round(nameSize.height)
        var enH: CGFloat = 0
        if !enLabel.isHidden {
            let enSize = enLabel.sizeThatFits(NSSize(width: cardW - 24, height: .greatestFiniteMagnitude))
            enH = round(enSize.height)
        }
        // 总高度
        let totalH = keyRowH + spacing + nameH + (enH > 0 ? spacing + enH : 0)
        // 从顶部开始布局（而不是居中），确保内容多的时候底部元素不会被裁剪
        // 如果内容能放下则居中，放不下则从顶部开始
        let topMargin: CGFloat = 8
        var curY: CGFloat
        if totalH <= cardH - topMargin * 2 {
            // 内容能放下，居中
            curY = round((cardH + totalH) / 2)
        } else {
            // 内容放不下，从顶部开始
            curY = cardH - topMargin
        }
        // keyRow（最顶部）
        curY -= keyRowH
        keyRow.frame = NSRect(x: round((cardW - keyRowW) / 2), y: curY, width: keyRowW, height: keyRowH)
        keyRow.layoutSubtreeIfNeeded()
        curY -= spacing
        // nameLabel（中间）
        curY -= nameH
        nameLabel.frame = NSRect(x: round((cardW - nameW) / 2), y: curY, width: nameW, height: nameH)
        curY -= spacing
        // enLabel（最底部）
        if enH > 0 {
            curY -= enH
            enLabel.frame = NSRect(x: round((cardW - nameW) / 2), y: curY, width: nameW, height: enH)
        }
        // 所有子视图frame取整对齐像素网格（递归，包括keyRow内部的键帽）
        alignSubviewsToPixels(self)
    }

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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
        updateLayerContentsScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateLayerContentsScale()
    }

    private func updateLayerContentsScale() {
        guard let scale = window?.backingScaleFactor else { return }
        layer?.contentsScale = scale
        gradientLayer?.contentsScale = scale
        highlightLayer?.contentsScale = scale
        bottomShadowLayer?.contentsScale = scale
        glowLayers.forEach { $0.contentsScale = scale }
        // 边框宽度根据屏幕scale调整，确保物理像素为整数
        let pixelBorder = 1.0 / scale
        layer?.borderWidth = pixelBorder
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        if let ta = trackingArea { addTrackingArea(ta) }
    }

    override func mouseEntered(with event: NSEvent) {
        // trackingArea 使用 .activeAlways：App 失活（浮动窗口叠在其他应用上）时也能收到 enter/exit
        applyHoverState(true)
    }

    override func mouseExited(with event: NSEvent) {
        applyHoverState(false)
    }

    // 全局悬停状态控制：快捷键不变色，SPICE指令保留变色
    func applyHoverState(_ active: Bool) {
        if isHovered == active { return }
        isHovered = active
        // 快捷键卡片悬停时不变色，直接返回
        if !isCommand { return }
        // SPICE指令卡片悬停时变色
        layer?.removeAllAnimations()
        gradientLayer?.removeAllAnimations()
        glowLayers.forEach { $0.removeAllAnimations() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if active {
            layer?.transform = CATransform3DMakeTranslation(0, 8, 0)
            layer?.zPosition = 1
            glowLayers.forEach { $0.opacity = 1 }
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
            layer?.borderWidth = 1
            gradientLayer?.colors = [
                NSColor.controlBackgroundColor.withAlphaComponent(1.0).cgColor,
                NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
            ]
            layer?.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
            layer?.shadowRadius = 14
            layer?.shadowOffset = NSSize(width: 0, height: -5)
            layer?.shadowOpacity = 1
        } else {
            layer?.transform = CATransform3DIdentity
            layer?.zPosition = 0
            glowLayers.forEach { $0.opacity = 0 }
            gradientLayer?.colors = [
                NSColor(white: 0.98, alpha: 1.0).cgColor,
                NSColor(white: 0.91, alpha: 1.0).cgColor
            ]
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
            layer?.borderWidth = 0.5
            layer?.shadowColor = NSColor.black.withAlphaComponent(0.30).cgColor
            layer?.shadowRadius = 16
            layer?.shadowOffset = NSSize(width: 0, height: -6)
            layer?.shadowOpacity = 1
        }
        CATransaction.commit()
    }

    @objc private func handleClick() {
        onClick?()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isCommand {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}

// MARK: - 自定义卡片网格（手动 layout，避免 NSStackView 约束冲突）

final class ComponentGridView: NSView {
    private let items: [ShortcutItem]
    private let sectionIndex: Int
    private let cols = 3
    private let spacing: CGFloat = 8
    private let maxCardWidth: CGFloat = 250
    private var cardViews: [ComponentCardView] = []
    private var heightConstraint: NSLayoutConstraint?
    var onCommandClick: ((ShortcutItem) -> Void)?
    var onCardAdded: ((ComponentCardView, Int, String) -> Void)?

    init(items: [ShortcutItem], sectionIndex: Int) {
        self.items = items
        self.sectionIndex = sectionIndex
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for item in items {
            let card = ComponentCardView(item: item)
            card.translatesAutoresizingMaskIntoConstraints = true
            card.autoresizingMask = []
            if item.combos.first?.first?.hasPrefix(".") == true {
                card.onClick = { [weak self] in self?.onCommandClick?(item) }
            }
            addSubview(card)
            cardViews.append(card)
        }
    }

    // 在 onCardAdded 回调设置完成后调用，确保卡片能被正确注册
    func notifyCardsAdded() {
        for card in cardViews {
            let searchText = (card.item.combos.first?.first ?? "") + " " + card.item.desc
            onCardAdded?(card, sectionIndex, searchText.lowercased())
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func cardWidth(for width: CGFloat) -> CGFloat {
        max((width - CGFloat(cols - 1) * spacing) / CGFloat(cols), 80)
    }

    // 判断卡片是否需要跨两列（长内容）
    private func shouldSpan(_ card: ComponentCardView) -> Bool {
        let desc = card.item.desc
        // 提取中文名和英文名（用lastIndex，SPICE指令可能有两个括号）
        var cnName = desc
        var enName = ""
        if let lp = desc.lastIndex(of: "（"), let rp = desc.lastIndex(of: "）"), lp < rp {
            cnName = String(desc[..<lp]).trimmingCharacters(in: .whitespaces)
            enName = String(desc[desc.index(after: lp)..<rp]).trimmingCharacters(in: .whitespaces)
        }
        let comboCount = card.item.combos.first?.count ?? 0
        // 阈值：包含中文的enName阈值8（中文宽度大），全英文的阈值12
        let containsChinese = enName.range(of: "\\p{Han}", options: .regularExpression) != nil
        let enThreshold: CGFloat = containsChinese ? 8 : 12
        // 组合键>=2的跨列（键帽需要更多宽度）；中文名>6或英文名超阈值也跨列
        return cnName.count > 6 || comboCount >= 2 || CGFloat(enName.count) > enThreshold
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let cw = cardWidth(for: w)
        // 只布局可见的卡片（搜索过滤后隐藏的卡片不占空间）
        let visibleCards = cardViews.filter { !$0.isHidden }
        let totalWidth = cw * CGFloat(cols) + spacing * CGFloat(cols - 1)
        let startX = (w - totalWidth) / 2

        // 智能紧凑排列：当前行剩1列时优先从后面找普通卡片填上，不留空
        var remaining = visibleCards
        var rows: [(y: CGFloat, cards: [(x: CGFloat, width: CGFloat, card: ComponentCardView)])] = []
        var currentCol = 0
        rows.append((y: 0, cards: []))

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
                // 当前行放不下任何卡片，换行
                currentCol = 0
                rows.append((y: 0, cards: []))
                continue
            }
            let card = remaining.remove(at: foundIdx)
            let span = shouldSpan(card) ? 2 : 1
            let cardX = startX + CGFloat(currentCol) * (cw + spacing)
            let cardW = span == 2 ? (cw * 2 + spacing) : cw
            rows[rows.count - 1].cards.append((x: cardX, width: cardW, card: card))
            currentCol += span
        }

        // 计算每行y坐标（Cocoa y轴从下往上，第一行在最下面）
        let rowCount = rows.count
        for (rowIdx, _) in rows.enumerated() {
            let y = CGFloat(rowCount - 1 - rowIdx) * (cw + spacing)
            rows[rowIdx].y = y
        }

        // 设置卡片frame
        for row in rows {
            for item in row.cards {
                item.card.frame = NSRect(x: item.x, y: row.y, width: item.width, height: cw)
                item.card.updateTrackingAreas()
            }
        }

        // 隐藏的卡片移到视野外，避免拦截事件
        for card in cardViews where card.isHidden {
            card.frame = NSRect(x: -10000, y: -10000, width: cw, height: cw)
        }

        let totalHeight = CGFloat(rowCount) * cw + CGFloat(rowCount - 1) * spacing
        if heightConstraint == nil {
            heightConstraint = heightAnchor.constraint(equalToConstant: totalHeight)
            heightConstraint?.isActive = true
        } else if abs(heightConstraint!.constant - totalHeight) > 1 {
            heightConstraint?.constant = totalHeight
        }
    }

    func invalidateLayout() {
        needsLayout = true
    }
}

// MARK: - 翻转视图（NSScrollView 的 documentView 需要 flipped 坐标，否则内容从底部开始）

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - 首页软件卡片网格（3列等宽正方形，与详情页风格一致）

final class HomeSoftwareGridView: NSView {
    private let cards: [SoftwareCardView]
    private let cols = 3
    private let spacing: CGFloat = 12
    private var heightConstraint: NSLayoutConstraint?

    init(cards: [SoftwareCardView]) {
        self.cards = cards
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for card in cards {
            card.translatesAutoresizingMaskIntoConstraints = true
            card.autoresizingMask = []
            addSubview(card)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func cardWidth(for width: CGFloat) -> CGFloat {
        max((width - CGFloat(cols - 1) * spacing) / CGFloat(cols), 80)
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let cw = round(cardWidth(for: w))
        // 只布局可见的卡片（搜索过滤后隐藏的卡片不占空间）
        let visibleCards = cards.filter { !$0.isHidden }
        let totalWidth = cw * CGFloat(cols) + spacing * CGFloat(cols - 1)
        let startX = round((w - totalWidth) / 2)
        let rows = ceil(CGFloat(visibleCards.count) / CGFloat(cols))
        let totalHeight = round(rows * cw + (rows - 1) * spacing)
        for (i, card) in visibleCards.enumerated() {
            let row = i / cols
            let col = i % cols
            let x = round(startX + CGFloat(col) * (cw + spacing))
            let y = round((rows - 1 - CGFloat(row)) * (cw + spacing))
            card.frame = NSRect(x: x, y: y, width: cw, height: cw)
            card.updateTrackingAreas()
        }
        // 隐藏的卡片移到视野外，避免拦截事件
        for card in cards where card.isHidden {
            card.frame = NSRect(x: -10000, y: -10000, width: cw, height: cw)
        }
        if heightConstraint == nil {
            heightConstraint = heightAnchor.constraint(equalToConstant: totalHeight)
            heightConstraint?.isActive = true
        } else if abs(heightConstraint!.constant - totalHeight) > 1 {
            heightConstraint?.constant = totalHeight
        }
    }
}

// MARK: - 软件卡片（首页用，NSButton 子类确保点击可靠 + 立体感 + 悬停）

final class SoftwareCardView: NSButton {
    let guide: SoftwareGuide?
    let isPlaceholder: Bool
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var highlightLayer: CALayer?
    private var nameLabel: ClickThroughLabel!
    private var infoLabel: ClickThroughLabel!
    private var updatedLabel: ClickThroughLabel!
    private var iconBg: NSView!
    private var iconView: NSImageView!
    private var lastCardWidth: CGFloat = 0

    convenience init(guide: SoftwareGuide) {
        self.init(guide: guide, isPlaceholder: false)
    }

    convenience init(placeholderTitle: String) {
        self.init(guide: nil, isPlaceholder: true, placeholderTitle: placeholderTitle)
    }

    private init(guide: SoftwareGuide?, isPlaceholder: Bool, placeholderTitle: String = "") {
        self.guide = guide
        self.isPlaceholder = isPlaceholder
        super.init(frame: .zero)
        bezelStyle = .shadowlessSquare
        isBordered = false
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = false
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -3)
        layer?.shadowRadius = 10
        layer?.shadowOpacity = 1
        target = self
        action = #selector(buttonClicked)
        if isPlaceholder { isEnabled = false }

        // 渐变背景层（不透明，避免半透明导致字体模糊）
        let grad = CAGradientLayer()
        grad.cornerRadius = 14
        let cardBg = NSColor(white: 0.985, alpha: 1.0)
        let cardBg2 = NSColor(white: 0.97, alpha: 1.0)
        grad.colors = isPlaceholder
            ? [NSColor(white: 0.97, alpha: 1.0).cgColor,
               NSColor(white: 0.95, alpha: 1.0).cgColor]
            : [cardBg.cgColor, cardBg2.cgColor]
        grad.locations = [0, 1]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint = CGPoint(x: 0, y: 1)
        layer?.insertSublayer(grad, at: 0)
        gradientLayer = grad

        // 顶部高光线
        let hl = CALayer()
        hl.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        hl.cornerRadius = 14
        hl.masksToBounds = true
        layer?.insertSublayer(hl, above: grad)
        highlightLayer = hl

        // 图标背景
        let iconBg = NSView()
        iconBg.wantsLayer = true
        iconBg.layer?.cornerRadius = 12
        iconBg.layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
        iconBg.layer?.shadowOffset = NSSize(width: 0, height: -1)
        iconBg.layer?.shadowRadius = 4
        iconBg.layer?.shadowOpacity = 1
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        self.iconBg = iconBg

        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)
        self.iconView = iconView

        if isPlaceholder {
            iconBg.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.25).cgColor
            let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            iconView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            iconView.contentTintColor = .secondaryLabelColor
        } else {
            iconBg.layer?.backgroundColor = NSColor.systemBlue.cgColor
            let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            let iconName = guide?.icon ?? "command"
            iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
                ?? NSImage(systemSymbolName: "command", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            iconView.contentTintColor = .white
        }

        // 文字
        let nameText = isPlaceholder ? placeholderTitle : (guide?.name ?? "")
        let nameLabel = ClickThroughLabel(labelWithString: nameText)
        nameLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = isPlaceholder ? .tertiaryLabelColor : .labelColor
        self.nameLabel = nameLabel

        let infoText: String
        if isPlaceholder {
            infoText = "敬请期待"
        } else {
            infoText = "v\(guide?.version ?? "") · \(guide?.totalShortcuts ?? 0) 个快捷键"
        }
        let infoLabel = ClickThroughLabel(labelWithString: infoText)
        infoLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        infoLabel.textColor = .tertiaryLabelColor
        self.infoLabel = infoLabel

        let updatedText = isPlaceholder ? "" : "更新于 \(guide?.lastUpdated ?? "")"
        let updatedLabel = ClickThroughLabel(labelWithString: updatedText)
        updatedLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        updatedLabel.textColor = .tertiaryLabelColor
        updatedLabel.isHidden = isPlaceholder
        self.updatedLabel = updatedLabel

        let textStack = NSStackView(views: [nameLabel, infoLabel, updatedLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let hStack = NSStackView(views: [iconBg, textStack])
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hStack)

        NSLayoutConstraint.activate([
            iconBg.widthAnchor.constraint(equalToConstant: 48),
            iconBg.heightAnchor.constraint(equalToConstant: 48),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            hStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
        highlightLayer?.frame = NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        // 字体和图标随卡片大小动态缩放
        let w = bounds.width
        if w > 0 && abs(w - lastCardWidth) > 1 {
            lastCardWidth = w
            let scale = w / 200  // 基准宽度200pt
            let nameSize = round(max(11, min(22, 16 * scale)))
            let infoSize = round(max(8, min(15, 11 * scale)))
            let updatedSize = round(max(7, min(14, 10 * scale)))
            let iconSize = round(max(28, min(64, 48 * scale)))
            let iconInnerSize = round(max(16, min(40, 28 * scale)))
            nameLabel?.font = NSFont.systemFont(ofSize: nameSize, weight: .bold)
            infoLabel?.font = NSFont.systemFont(ofSize: infoSize, weight: .regular)
            updatedLabel?.font = NSFont.systemFont(ofSize: updatedSize, weight: .regular)
            // 更新图标大小约束
            if let iconBg = iconBg, let iconView = iconView {
                for c in iconBg.constraints {
                    if c.firstAttribute == .width || c.firstAttribute == .height {
                        c.constant = iconSize
                    }
                }
                for c in iconView.constraints {
                    if c.firstAttribute == .width || c.firstAttribute == .height {
                        c.constant = iconInnerSize
                    }
                }
            }
        }
        // 所有子视图frame取整对齐像素网格
        alignSubviewsToPixels(self)
    }

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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayerContentsScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateLayerContentsScale()
    }

    private func updateLayerContentsScale() {
        guard let scale = window?.backingScaleFactor else { return }
        layer?.contentsScale = scale
        gradientLayer?.contentsScale = scale
        highlightLayer?.contentsScale = scale
        // 边框宽度根据屏幕scale调整
        let pixelBorder = 1.0 / scale
        layer?.borderWidth = pixelBorder
        // 非Retina屏边框颜色调深
        if scale < 2.0 {
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
        } else {
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func buttonClicked() {
        guard !isPlaceholder else { return }
        onCardClick?()
    }

    var onCardClick: (() -> Void)?

    // 手型光标
    override func resetCursorRects() {
        super.resetCursorRects()
        if !isPlaceholder {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    // 悬停效果
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        if let ta = trackingArea { addTrackingArea(ta) }
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isPlaceholder else { return }
        // 用 layer.transform 实现上浮，不修改 frame（避免被 layout 覆盖）
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        layer?.transform = CATransform3DMakeTranslation(0, 6, 0)
        layer?.zPosition = 1
        CATransaction.commit()
        gradientLayer?.colors = [
            NSColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.88, green: 0.93, blue: 1.0, alpha: 1.0).cgColor
        ]
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
        layer?.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
        layer?.shadowRadius = 16
        layer?.shadowOffset = NSSize(width: 0, height: -6)
        highlightLayer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        layer?.transform = CATransform3DIdentity
        layer?.zPosition = 0
        CATransaction.commit()
        gradientLayer?.colors = isPlaceholder
            ? [NSColor(white: 0.97, alpha: 1.0).cgColor,
               NSColor(white: 0.95, alpha: 1.0).cgColor]
            : [NSColor(white: 0.985, alpha: 1.0).cgColor,
               NSColor(white: 0.97, alpha: 1.0).cgColor]
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
        layer?.shadowRadius = 10
        layer?.shadowOffset = NSSize(width: 0, height: -3)
        highlightLayer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
    }

    override func mouseDown(with event: NSEvent) {
        guard !isPlaceholder else { super.mouseDown(with: event); return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            self.animator().frame = self.frame.offsetBy(dx: 0, dy: 1)
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard !isPlaceholder else { super.mouseUp(with: event); return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            self.animator().frame = self.frame.offsetBy(dx: 0, dy: -1)
        }
        super.mouseUp(with: event)
    }
}

// MARK: - 应用主体

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var eventHandlerRef: EventHandlerRef?
    private var guides: [SoftwareGuide] = []
    private var containerView: NSView?

    // 详情页状态
    private var currentGuide: SoftwareGuide?
    private var detailSearchField: NSSearchField?
    private var sectionTabs: SectionTabView?
    private var detailResultLabel: NSTextField?
    private var detailNoResults: NSView?
    private var sectionContainers: [NSView] = []
    private var rowRefs: [(view: NSView, sectionIndex: Int, searchText: String)] = []
    private var selectedSection: Int = -1
    private var scrollObserver: NSObjectProtocol?
    private var hoverUpdateTimer: Timer?

    private let sectionColors: [NSColor] = [
        .systemBlue, .systemPurple, .systemGreen, .systemOrange, .systemRed, .systemTeal
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        appDelegateRef = self
        NSApp.setActivationPolicy(.accessory)
        loadAllGuides()
        setupStatusItem()
        setupWindow()
        registerHotKey()
        showHome()
        showWindow()
        // 延迟再次显示，确保窗口可见
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showWindow()
        }

        // 全局鼠标移动+滚轮监听：修复快速滑动/滚轮滚动时多个卡片被点亮无法熄灭的问题
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel]) { [weak self] event in
            self?.updateAllCardHoverStates()
            return event
        }

        // 定期更新悬停状态（80ms），确保滚轮滚动时悬停状态正确更新
        // 必须添加到 common runloop mode，否则滚轮滚动时（event tracking mode）Timer 不触发
        hoverUpdateTimer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateAllCardHoverStates()
        }
        if let timer = hoverUpdateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc private func updateAllCardHoverStates() {
        guard let win = window else { return }
        let mouseLoc = win.mouseLocationOutsideOfEventStream
        for ref in rowRefs {
            if let card = ref.view as? ComponentCardView {
                // 直接在窗口坐标和卡片坐标间转换，更可靠
                let cardPoint = card.convert(mouseLoc, from: nil)
                let mouseInCard = card.bounds.contains(cardPoint)
                card.applyHoverState(mouseInCard)
            }
        }
    }

    // 双击已运行的 app 时重新显示窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }

    // MARK: 加载所有指南

    private func loadAllGuides() {
        guides.removeAll()
        // 从 app bundle Resources/guides/ 加载
        if let guidesDir = Bundle.main.resourceURL?.appendingPathComponent("guides") {
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: guidesDir, includingPropertiesForKeys: nil) {
                for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    if file.pathExtension == "md", let text = try? String(contentsOf: file, encoding: .utf8) {
                        guides.append(GuideParser.load(from: text))
                    }
                }
            }
        }
        // 兜底：从 app 同级目录 guides/ 加载（开发模式）
        if guides.isEmpty, let appPath = Bundle.main.bundlePath as NSString? {
            let devGuides = (appPath.deletingLastPathComponent as NSString).appendingPathComponent("../guides")
            let devURL = URL(fileURLWithPath: devGuides).standardizedFileURL
            if let files = try? FileManager.default.contentsOfDirectory(at: devURL, includingPropertiesForKeys: nil) {
                for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    if file.pathExtension == "md", let text = try? String(contentsOf: file, encoding: .utf8) {
                        guides.append(GuideParser.load(from: text))
                    }
                }
            }
        }
    }

    // MARK: 菜单栏图标

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let img = NSImage(systemSymbolName: "book.closed", accessibilityDescription: "KeyRef 快捷键手册")?.withSymbolConfiguration(config)
            img?.isTemplate = true
            button.image = img
            button.imagePosition = .imageOnly
        }
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "显示 / 隐藏（⌃⌥L）", action: #selector(toggleWindow), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        // 软件指南子菜单
        let guidesMenu = NSMenu(title: "软件指南")
        for (i, guide) in guides.enumerated() {
            let item = NSMenuItem(title: guide.name, action: #selector(openGuideFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            guidesMenu.addItem(item)
        }
        let guidesItem = NSMenuItem(title: "软件指南", action: nil, keyEquivalent: "")
        guidesItem.submenu = guidesMenu
        menu.addItem(guidesItem)
        menu.addItem(.separator())
        let home = NSMenuItem(title: "返回首页", action: #selector(goHome), keyEquivalent: "")
        home.target = self
        menu.addItem(home)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    // MARK: 窗口

    private func setupWindow() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = "KeyRef"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.titlebarSeparatorStyle = .none
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.acceptsMouseMovedEvents = true
        // 宽度固定480，高度可纵向拉升（400 ~ 3000）
        win.minSize = NSSize(width: 480, height: 400)
        win.maxSize = NSSize(width: 480, height: 3000)
        win.center()

        let vibrancy = NSVisualEffectView(frame: win.contentLayoutRect)
        vibrancy.material = .popover
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = 12
        vibrancy.layer?.masksToBounds = true
        vibrancy.layer?.borderWidth = 0.5
        vibrancy.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        vibrancy.autoresizingMask = [.width, .height]
        win.contentView = vibrancy

        // 容器视图（用于首页/详情页切换）
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        vibrancy.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: vibrancy.topAnchor),
            container.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: vibrancy.bottomAnchor),
        ])
        containerView = container
        window = win
    }

    // MARK: 首页

    private func showHome() {
        guard let container = containerView else { return }
        // 清除详情页
        container.subviews.forEach { $0.removeFromSuperview() }
        sectionContainers.removeAll()
        rowRefs.removeAll()

        // 标题
        let titleLabel = NSTextField(labelWithString: "KeyRef")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: "多软件快捷键速查")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 唤出指令提示（键帽样式）
        let hotkeyRow = NSStackView()
        hotkeyRow.orientation = .horizontal
        hotkeyRow.alignment = .centerY
        hotkeyRow.spacing = 4
        hotkeyRow.translatesAutoresizingMaskIntoConstraints = false

        let hotkeyLabel = NSTextField(labelWithString: "唤出：")
        hotkeyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hotkeyLabel.textColor = .tertiaryLabelColor
        hotkeyRow.addArrangedSubview(hotkeyLabel)

        let ctrlKey = KeycapView(key: "Ctrl")
        ctrlKey.translatesAutoresizingMaskIntoConstraints = false
        hotkeyRow.addArrangedSubview(ctrlKey)

        let plus1 = NSTextField(labelWithString: "+")
        plus1.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        plus1.textColor = .tertiaryLabelColor
        hotkeyRow.addArrangedSubview(plus1)

        let altKey = KeycapView(key: "Alt")
        altKey.translatesAutoresizingMaskIntoConstraints = false
        hotkeyRow.addArrangedSubview(altKey)

        let plus2 = NSTextField(labelWithString: "+")
        plus2.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        plus2.textColor = .tertiaryLabelColor
        hotkeyRow.addArrangedSubview(plus2)

        let lKey = KeycapView(key: "L")
        lKey.translatesAutoresizingMaskIntoConstraints = false
        hotkeyRow.addArrangedSubview(lKey)

        // 软件卡片列表：已有软件 + 占位卡片
        var cardList: [SoftwareCardView] = []
        for guide in guides {
            let card = SoftwareCardView(guide: guide)
            card.onCardClick = { [weak self] in self?.showDetail(guide: guide) }
            cardList.append(card)
        }
        // 占位卡片
        let placeholders = ["Altium Designer", "KiCad", "VS Code", "更多软件…", "敬请期待", "敬请期待"]
        for name in placeholders {
            let card = SoftwareCardView(placeholderTitle: name)
            cardList.append(card)
        }

        // 3列等宽正方形网格（与详情页风格一致）
        let gridView = HomeSoftwareGridView(cards: cardList)
        gridView.translatesAutoresizingMaskIntoConstraints = false

        objc_setAssociatedObject(self, "homeCardRefs", cardList.map { ($0 as NSView, "") }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // 滚动视图（内容超出窗口时可滚动）
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let docView = FlippedView()
        docView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = docView

        docView.addSubview(titleLabel)
        docView.addSubview(subtitleLabel)
        docView.addSubview(hotkeyRow)
        docView.addSubview(gridView)

        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            docView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            titleLabel.topAnchor.constraint(equalTo: docView.topAnchor, constant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            hotkeyRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            hotkeyRow.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            gridView.topAnchor.constraint(equalTo: hotkeyRow.bottomAnchor, constant: 20),
            gridView.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 16),
            gridView.trailingAnchor.constraint(equalTo: docView.trailingAnchor, constant: -16),
            gridView.bottomAnchor.constraint(equalTo: docView.bottomAnchor, constant: -20),
        ])
        // 滚动到顶部
        DispatchQueue.main.async {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    @objc private func homeSearchChanged(_ sender: NSSearchField) {
        let q = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let refs = objc_getAssociatedObject(self, "homeCardRefs") as? [(view: NSView, searchText: String)] {
            for ref in refs {
                ref.view.isHidden = !q.isEmpty && !ref.searchText.contains(q)
            }
        }
    }

    // MARK: 详情页

    private func showDetail(guide: SoftwareGuide) {
        guard let container = containerView else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        sectionContainers.removeAll()
        rowRefs.removeAll()
        selectedSection = -1
        currentGuide = guide

        // 返回按钮
        let backBtn = NSButton(title: "‹ 首页", target: self, action: #selector(goHome))
        backBtn.bezelStyle = .inline
        backBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        backBtn.contentTintColor = .controlAccentColor
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        // 软件名 + 版本
        let nameLabel = NSTextField(labelWithString: guide.name)
        nameLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = .labelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let versionLabel = NSTextField(labelWithString: "v\(guide.version) · 适配 \(guide.minVersion)+ · 更新 \(guide.lastUpdated)")
        versionLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        // 搜索框
        let search = NSSearchField()
        search.placeholderString = "搜索快捷键或功能…"
        search.font = NSFont.systemFont(ofSize: 13)
        search.target = self
        search.action = #selector(detailSearchChanged(_:))
        search.translatesAutoresizingMaskIntoConstraints = false
        detailSearchField = search

        // 分区切换（多行换行标签）
        var tabTitles = ["全部"]
        for s in guide.sections { tabTitles.append(shortLabel(for: s.title)) }
        let sectionTab = SectionTabView()
        sectionTab.configure(titles: tabTitles)
        sectionTab.alwaysHighlightTitles = ["SPICE 指令"]
        sectionTab.translatesAutoresizingMaskIntoConstraints = false
        sectionTab.onSelect = { [weak self] idx in
            self?.selectedSection = idx - 1
            self?.detailSearchField?.stringValue = ""
            self?.applyDetailFilter(query: "")
        }
        sectionTabs = sectionTab

        // 结果计数
        let result = NSTextField(labelWithString: "")
        result.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        result.textColor = .secondaryLabelColor
        result.isHidden = true
        result.translatesAutoresizingMaskIntoConstraints = false
        detailResultLabel = result

        // 内容滚动区
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        for (i, section) in guide.sections.enumerated() {
            let container = NSStackView()
            container.orientation = .vertical
            container.alignment = .leading
            container.spacing = 8
            container.translatesAutoresizingMaskIntoConstraints = false
            sectionContainers.append(container)

            let color = i < sectionColors.count ? sectionColors[i] : .systemGray
            let header = makeSectionHeader(title: cleanTitle(section.title), count: section.items.count, color: color)
            header.translatesAutoresizingMaskIntoConstraints = false
            container.addArrangedSubview(header)
            header.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

            if !section.items.isEmpty {
                let grid = makeComponentGrid(for: section.items, sectionIndex: i)
                grid.translatesAutoresizingMaskIntoConstraints = false
                container.addArrangedSubview(grid)
                grid.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
            }

            for note in section.notes {
                let callout = CalloutView(text: note, kind: section.title.contains("注意") ? .warning : .note)
                callout.translatesAutoresizingMaskIntoConstraints = false
                container.addArrangedSubview(callout)
                callout.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
                rowRefs.append((view: callout, sectionIndex: i, searchText: note.lowercased()))
            }

            contentStack.addArrangedSubview(container)
            container.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }

        // 底部
        let footer = NSTextField(labelWithString: "⌃⌥L 切换显示 · 菜单栏图标可返回首页 / 退出")
        footer.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        footer.textColor = .tertiaryLabelColor
        footer.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(footer)

        // 无结果
        let noResults = makeNoResultsView()
        noResults.translatesAutoresizingMaskIntoConstraints = false
        noResults.isHidden = true
        detailNoResults = noResults

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(contentStack)
        doc.addSubview(noResults)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: doc.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -14),
            noResults.centerXAnchor.constraint(equalTo: doc.centerXAnchor),
            noResults.centerYAnchor.constraint(equalTo: doc.centerYAnchor),
        ])
        scroll.documentView = doc
        // 监听滚动视图内容偏移变化，修复滚轮滚动时多个卡片被点亮无法熄灭的bug
        if let obs = scrollObserver { NotificationCenter.default.removeObserver(obs) }
        scroll.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in
            self?.updateAllCardHoverStates()
        }
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        container.addSubview(backBtn)
        container.addSubview(nameLabel)
        container.addSubview(versionLabel)
        container.addSubview(search)
        container.addSubview(sectionTab)
        container.addSubview(result)
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            backBtn.topAnchor.constraint(equalTo: container.topAnchor, constant: 36),
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            backBtn.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.topAnchor.constraint(equalTo: backBtn.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            versionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            search.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 10),
            search.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            search.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            sectionTab.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 8),
            sectionTab.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            sectionTab.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            result.topAnchor.constraint(equalTo: sectionTab.bottomAnchor, constant: 4),
            result.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            scroll.topAnchor.constraint(equalTo: result.bottomAnchor, constant: 2),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    @objc private func goHome() { showHome() }

    // MARK: - 指令详细说明弹窗

    private func showCommandDetail(item: ShortcutItem) {
        let cmdName = item.combos.first?.first ?? "指令"
        let detailWin = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                                 styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                                 backing: .buffered, defer: false)
        detailWin.title = cmdName
        detailWin.titlebarAppearsTransparent = true
        detailWin.titleVisibility = .hidden
        detailWin.isReleasedWhenClosed = false
        detailWin.level = .floating
        detailWin.minSize = NSSize(width: 400, height: 300)

        let vibrancy = NSVisualEffectView(frame: detailWin.contentLayoutRect)
        vibrancy.material = .popover
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = 12
        vibrancy.layer?.masksToBounds = true
        detailWin.contentView = vibrancy

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        vibrancy.addSubview(container)

        let titleLabel = NSTextField(labelWithString: cmdName)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = NSTextField(labelWithString: item.desc)
        descLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 0
        descLabel.preferredMaxLayoutWidth = 460
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        // 详细说明文本（格式化：标签加粗，调整行间距）
        let detailText = item.detail.isEmpty ? "暂无详细说明。" : item.detail
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = 4
        paraStyle.paragraphSpacing = 8
        let attrStr = NSMutableAttributedString(string: detailText, attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paraStyle
        ])
        // 让"语法："、"参数说明："、"示例："、"常用参数："、"用途："等标签加粗
        let labels = ["语法：", "参数说明：", "示例：", "常用参数：", "用途："]
        for label in labels {
            var searchRange = NSRange(location: 0, length: attrStr.length)
            while searchRange.location < attrStr.length {
                let foundRange = (attrStr.string as NSString).range(of: label, options: [], range: searchRange)
                if foundRange.location != NSNotFound {
                    attrStr.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .semibold), range: foundRange)
                    searchRange = NSRange(location: foundRange.location + foundRange.length, length: attrStr.length - foundRange.location - foundRange.length)
                } else { break }
            }
        }
        let detailLabel = NSTextField(labelWithAttributedString: attrStr)
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 0
        detailLabel.preferredMaxLayoutWidth = 460
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = NSButton(title: "关闭", target: detailWin, action: #selector(NSWindow.close))
        closeBtn.bezelStyle = .rounded
        closeBtn.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(descLabel)
        container.addSubview(detailLabel)
        container.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: vibrancy.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: vibrancy.bottomAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 16),
            detailLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: closeBtn.topAnchor, constant: -16),
            closeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            closeBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        detailWin.center()
        detailWin.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showNotesPage() {
        guard let container = containerView, let guide = currentGuide else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        // 返回按钮
        let backBtn = NSButton(title: "‹ 返回", target: self, action: #selector(backToDetail))
        backBtn.bezelStyle = .inline
        backBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        backBtn.contentTintColor = .controlAccentColor
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "⚠️ 特别注意事项")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let notesCount = guide.sections.reduce(0) { $0 + $1.notes.count }
        let subtitleLabel = NSTextField(labelWithString: "\(guide.name) · 共 \(notesCount) 条注意事项")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 内容滚动区
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        var noteIndex = 1
        for section in guide.sections where !section.notes.isEmpty {
            // 分区标题
            let sectionTitle = NSTextField(labelWithString: cleanTitle(section.title))
            sectionTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            sectionTitle.textColor = .controlAccentColor
            sectionTitle.translatesAutoresizingMaskIntoConstraints = false
            contentStack.addArrangedSubview(sectionTitle)

            for note in section.notes {
                let callout = CalloutView(text: note, kind: .warning)
                callout.translatesAutoresizingMaskIntoConstraints = false
                contentStack.addArrangedSubview(callout)
                callout.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
                noteIndex += 1
            }
        }

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: doc.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -16),
        ])
        scroll.documentView = doc
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        container.addSubview(backBtn)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            backBtn.topAnchor.constraint(equalTo: container.topAnchor, constant: 36),
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            backBtn.heightAnchor.constraint(equalToConstant: 24),
            titleLabel.topAnchor.constraint(equalTo: backBtn.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scroll.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    @objc private func backToDetail() {
        if let guide = currentGuide { showDetail(guide: guide) }
    }

    @objc private func openGuideFromMenu(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx >= 0 && idx < guides.count else { return }
        showWindow()
        showDetail(guide: guides[idx])
    }

    @objc private func detailSearchChanged(_ sender: NSSearchField) {
        let q = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            sectionTabs?.selectedIndex = 0
            sectionTabs?.updateSelection()
            selectedSection = -1
        }
        applyDetailFilter(query: q.lowercased())
    }

    private func applyDetailFilter(query: String) {
        var visibleCount = 0
        for (idx, container) in sectionContainers.enumerated() {
            let sectionActive = (selectedSection == -1 || selectedSection == idx)
            if !sectionActive { container.isHidden = true; continue }
            var hasVisible = false
            for ref in rowRefs where ref.sectionIndex == idx {
                let match = query.isEmpty || ref.searchText.contains(query)
                ref.view.isHidden = !match
                if match { hasVisible = true; visibleCount += 1 }
            }
            container.isHidden = !hasVisible
        }
        if !query.isEmpty {
            detailResultLabel?.stringValue = "找到 \(visibleCount) 个结果"
            detailResultLabel?.isHidden = false
        } else {
            detailResultLabel?.isHidden = true
        }
        detailNoResults?.isHidden = (visibleCount > 0)

        // 递归查找所有 ComponentGridView 并强制重新布局（搜索过滤后可见卡片变化）
        func findAndRelayout(_ view: NSView) {
            if let grid = view as? ComponentGridView {
                grid.needsLayout = true
                grid.layoutSubtreeIfNeeded()
            }
            for sub in view.subviews {
                findAndRelayout(sub)
            }
        }
        for container in sectionContainers {
            findAndRelayout(container)
        }
    }

    // MARK: UI 组件

    private func makeSectionHeader(title: String, count: Int, color: NSColor) -> NSView {
        let h = NSStackView()
        h.orientation = .horizontal
        h.alignment = .centerY
        h.spacing = 8

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 14).isActive = true
        h.addArrangedSubview(dot)

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)
        label.textColor = .labelColor
        h.addArrangedSubview(label)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        h.addArrangedSubview(spacer)

        if count > 0 {
            let badge = NSTextField(labelWithString: "\(count)")
            badge.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            badge.textColor = .tertiaryLabelColor
            h.addArrangedSubview(badge)
        }
        return h
    }

    // 放置元件专用：3列方形卡片网格（自定义视图手动布局）
    private func makeComponentGrid(for items: [ShortcutItem], sectionIndex: Int) -> NSView {
        let grid = ComponentGridView(items: items, sectionIndex: sectionIndex)
        grid.onCommandClick = { [weak self] item in
            self?.showCommandDetail(item: item)
        }
        grid.onCardAdded = { [weak self] card, secIdx, text in
            self?.rowRefs.append((view: card, sectionIndex: secIdx, searchText: text))
        }
        grid.notifyCardsAdded()
        return grid
    }

    private func makeGrid(for items: [ShortcutItem], sectionIndex: Int) -> NSView {
        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 6
        grid.translatesAutoresizingMaskIntoConstraints = false

        for i in stride(from: 0, to: items.count, by: 2) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 8
            row.translatesAutoresizingMaskIntoConstraints = false

            let card1 = ShortcutCardView(item: items[i])
            card1.translatesAutoresizingMaskIntoConstraints = false
            card1.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(card1)
            rowRefs.append((view: card1, sectionIndex: sectionIndex, searchText: searchText(of: items[i])))

            if i + 1 < items.count {
                let card2 = ShortcutCardView(item: items[i + 1])
                card2.translatesAutoresizingMaskIntoConstraints = false
                card2.setContentHuggingPriority(.defaultLow, for: .horizontal)
                row.addArrangedSubview(card2)
                card1.widthAnchor.constraint(equalTo: card2.widthAnchor).isActive = true
                rowRefs.append((view: card2, sectionIndex: sectionIndex, searchText: searchText(of: items[i + 1])))
            } else {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                row.addArrangedSubview(spacer)
                card1.widthAnchor.constraint(equalTo: spacer.widthAnchor).isActive = true
            }

            grid.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        }
        return grid
    }

    private func makeNoResultsView() -> NSView {
        let v = NSStackView()
        v.orientation = .vertical
        v.alignment = .centerX
        v.spacing = 6
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        icon.contentTintColor = .tertiaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        v.addArrangedSubview(icon)
        let label = NSTextField(labelWithString: "没有找到匹配的快捷键")
        label.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        label.textColor = .secondaryLabelColor
        v.addArrangedSubview(label)
        return v
    }

    private func searchText(of item: ShortcutItem) -> String {
        (item.combos.flatMap { $0 }.joined(separator: " ") + " " + item.desc + " " + item.version).lowercased()
    }

    private func shortLabel(for title: String) -> String {
        var t = cleanTitle(title)
        if let r = t.range(of: "（") { t = String(t[..<r.lowerBound]) }
        if let r = t.range(of: "(") { t = String(t[..<r.lowerBound]) }
        // 去掉通用前缀，缩短分段标签
        t = t.replacingOccurrences(of: "原理图编辑器 — ", with: "")
        t = t.replacingOccurrences(of: "编辑器 — ", with: "")
        t = t.replacingOccurrences(of: "原理图编辑器 ", with: "")
        return t.trimmingCharacters(in: .whitespaces)
    }

    private func cleanTitle(_ title: String) -> String {
        var t = title
        if let r = t.range(of: "^[一二三四五六七八九十]+、", options: .regularExpression) {
            t = String(t[r.upperBound...])
        }
        t = t.unicodeScalars.filter { scalar in
            !(scalar.properties.isEmoji || scalar.properties.isEmojiPresentation)
        }.map(String.init).joined()
        return t.trimmingCharacters(in: .whitespaces)
    }

    // MARK: 窗口切换

    @objc func toggleWindow() {
        if let win = window, win.isVisible {
            win.orderOut(nil)
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        guard let win = window else { return }
        let mouse = NSEvent.mouseLocation
        let target = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let t = target {
            let f = t.visibleFrame
            let x = f.midX - win.frame.width / 2
            let y = f.midY - win.frame.height / 2
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    // MARK: 全局热键

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(),
                                         hotKeyHandler, 1, &eventType, nil, &eventHandlerRef)
        guard status == noErr else { return }
        let hotKeyID = EventHotKeyID(signature: OSType(0x4B52), id: 1) // "KR"
        RegisterEventHotKey(kHotKeyCode, kHotKeyModifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

// MARK: - 入口

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

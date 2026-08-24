import Cocoa
import Carbon.HIToolbox

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

    init(key: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92).cgColor

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

    init(text: String, kind: Kind = .note) {
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

        let label = NSTextField(wrappingLabelWithString: text)
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
            if i == selectedIndex {
                btn.contentTintColor = .controlAccentColor
                btn.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            } else {
                btn.contentTintColor = .secondaryLabelColor
                btn.font = NSFont.systemFont(ofSize: 12, weight: .regular)
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
    private let keyRow = NSStackView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let enLabel = NSTextField(labelWithString: "")
    private var lastFontSize: CGFloat = 0
    var onClick: (() -> Void)?

    init(item: ShortcutItem) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = false
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.1).cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        layer?.shadowRadius = 4
        layer?.shadowOpacity = 1

        // 点击手势
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)

        // 渐变背景
        let grad = CAGradientLayer()
        grad.cornerRadius = 12
        grad.colors = [
            NSColor.controlBackgroundColor.withAlphaComponent(0.75).cgColor,
            NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        ]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint = CGPoint(x: 0, y: 1)
        layer?.insertSublayer(grad, at: 0)
        gradientLayer = grad

        // 解析功能描述：中文名（英文名）
        let desc = item.desc
        var cnName = desc
        var enName = ""
        if let lp = desc.firstIndex(of: "（"), let rp = desc.firstIndex(of: "）") {
            cnName = String(desc[..<lp]).trimmingCharacters(in: .whitespaces)
            enName = String(desc[desc.index(after: lp)..<rp]).trimmingCharacters(in: .whitespaces)
        }

        // 键帽（支持组合键，多个键帽并排）
        keyRow.orientation = .horizontal
        keyRow.alignment = .centerY
        keyRow.spacing = 2
        keyRow.translatesAutoresizingMaskIntoConstraints = false

        if let combo = item.combos.first {
            for (ki, key) in combo.enumerated() {
                if ki > 0 {
                    let plus = NSTextField(labelWithString: "+")
                    plus.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
                    plus.textColor = .secondaryLabelColor
                    keyRow.addArrangedSubview(plus)
                }
                let keycap = KeycapView(key: key)
                keycap.translatesAutoresizingMaskIntoConstraints = false
                keyRow.addArrangedSubview(keycap)
            }
        }

        // 功能名
        nameLabel.stringValue = cnName
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // 英文名（可选）
        enLabel.stringValue = enName
        enLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        enLabel.textColor = .tertiaryLabelColor
        enLabel.alignment = .center
        enLabel.lineBreakMode = .byTruncatingTail
        enLabel.maximumNumberOfLines = 1
        enLabel.isHidden = enName.isEmpty
        enLabel.translatesAutoresizingMaskIntoConstraints = false

        let vStack = NSStackView(views: [keyRow, nameLabel, enLabel])
        vStack.orientation = .vertical
        vStack.alignment = .centerX
        vStack.spacing = 8
        vStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            vStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            vStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            vStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])
    }

    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
        // 字体随卡片宽度自适应
        let w = bounds.width
        if w > 0 && abs(w - lastFontSize) > 1 {
            lastFontSize = w
            let keycapSize = max(12, min(32, w * 0.085))
            let nameSize = max(11, min(26, w * 0.075))
            let enSize = max(9, min(20, w * 0.06))
            let plusSize = max(10, min(24, w * 0.065))
            nameLabel.font = NSFont.systemFont(ofSize: nameSize, weight: .semibold)
            enLabel.font = NSFont.systemFont(ofSize: enSize, weight: .regular)
            for sub in keyRow.arrangedSubviews {
                if let tf = sub as? NSTextField {
                    tf.font = NSFont.systemFont(ofSize: plusSize, weight: .semibold)
                } else if let kc = sub as? KeycapView {
                    kc.setFontSize(keycapSize)
                }
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        if let ta = trackingArea { addTrackingArea(ta) }
    }

    override func mouseEntered(with event: NSEvent) {
        // 悬停状态由全局 mouseMoved 监听器统一处理
    }

    override func mouseExited(with event: NSEvent) {
        // 悬停状态由全局 mouseMoved 监听器统一处理
    }

    // 全局悬停状态控制（防止快速滑动时 mouseExited 丢失）
    func applyHoverState(_ active: Bool) {
        if active {
            gradientLayer?.colors = [
                NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor,
                NSColor.controlAccentColor.withAlphaComponent(0.06).cgColor
            ]
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            layer?.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
            layer?.shadowRadius = 10
            layer?.shadowOffset = NSSize(width: 0, height: -3)
        } else {
            gradientLayer?.colors = [
                NSColor.controlBackgroundColor.withAlphaComponent(0.75).cgColor,
                NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
            ]
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
            layer?.shadowColor = NSColor.black.withAlphaComponent(0.1).cgColor
            layer?.shadowRadius = 4
            layer?.shadowOffset = NSSize(width: 0, height: -1)
        }
    }

    @objc private func handleClick() {
        onClick?()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
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
            let searchText = (item.combos.first?.first ?? "") + " " + item.desc
            onCardAdded?(card, sectionIndex, searchText.lowercased())
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func cardWidth(for width: CGFloat) -> CGFloat {
        max((width - CGFloat(cols - 1) * spacing) / CGFloat(cols), 80)
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let cw = cardWidth(for: w)
        let totalWidth = cw * CGFloat(cols) + spacing * CGFloat(cols - 1)
        let startX = (w - totalWidth) / 2
        let rows = ceil(CGFloat(items.count) / CGFloat(cols))
        let totalHeight = rows * cw + (rows - 1) * spacing
        for (i, card) in cardViews.enumerated() {
            let row = i / cols
            let col = i % cols
            let x = startX + CGFloat(col) * (cw + spacing)
            let y = (rows - 1 - CGFloat(row)) * (cw + spacing)  // Cocoa y轴从下往上
            card.frame = NSRect(x: x, y: y, width: cw, height: cw)
            card.updateTrackingAreas()
        }
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

// MARK: - 软件卡片（首页用，NSButton 子类确保点击可靠 + 立体感 + 悬停）

final class SoftwareCardView: NSButton {
    let guide: SoftwareGuide?
    let isPlaceholder: Bool
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var highlightLayer: CALayer?

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

        // 渐变背景层
        let grad = CAGradientLayer()
        grad.cornerRadius = 14
        grad.colors = isPlaceholder
            ? [NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor,
               NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor]
            : [NSColor.controlBackgroundColor.withAlphaComponent(0.85).cgColor,
               NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor]
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

        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

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

        let infoText: String
        if isPlaceholder {
            infoText = "敬请期待"
        } else {
            infoText = "v\(guide?.version ?? "") · \(guide?.totalShortcuts ?? 0) 个快捷键"
        }
        let infoLabel = ClickThroughLabel(labelWithString: infoText)
        infoLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        infoLabel.textColor = .tertiaryLabelColor

        let updatedText = isPlaceholder ? "" : "更新于 \(guide?.lastUpdated ?? "")"
        let updatedLabel = ClickThroughLabel(labelWithString: updatedText)
        updatedLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        updatedLabel.textColor = .tertiaryLabelColor
        updatedLabel.isHidden = isPlaceholder

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
            heightAnchor.constraint(equalToConstant: 84),
        ])
    }

    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
        highlightLayer?.frame = NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
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
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().frame = self.frame.offsetBy(dx: 0, dy: -2)
        }
        gradientLayer?.colors = [
            NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor,
            NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        ]
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
        layer?.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
        layer?.shadowRadius = 16
        layer?.shadowOffset = NSSize(width: 0, height: -6)
        highlightLayer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().frame = self.frame.offsetBy(dx: 0, dy: 2)
        }
        gradientLayer?.colors = isPlaceholder
            ? [NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor,
               NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor]
            : [NSColor.controlBackgroundColor.withAlphaComponent(0.85).cgColor,
               NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor]
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

        // 全局鼠标移动监听：修复快速滑动时多个卡片被点亮无法熄灭的问题
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateAllCardHoverStates()
            return event
        }
    }

    private func updateAllCardHoverStates() {
        guard window != nil else { return }
        let mouseScreen = NSEvent.mouseLocation
        for ref in rowRefs {
            if let card = ref.view as? ComponentCardView {
                // 用屏幕坐标判断鼠标是否在卡片内，更可靠
                if let cardWindow = card.window {
                    let cardFrameInWindow = card.convert(card.bounds, to: nil)
                    let cardFrameOnScreen = cardWindow.convertToScreen(cardFrameInWindow)
                    let mouseInCard = cardFrameOnScreen.contains(mouseScreen)
                    card.applyHoverState(mouseInCard)
                }
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
            let img = NSImage(systemSymbolName: "command", accessibilityDescription: "KeyRef 快捷键手册")
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
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 600),
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
        win.minSize = NSSize(width: 480, height: 400)
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

        // 搜索框
        let search = NSSearchField()
        search.placeholderString = "搜索软件、快捷键或指令…"
        search.font = NSFont.systemFont(ofSize: 14)
        search.target = self
        search.action = #selector(homeSearchChanged(_:))
        search.translatesAutoresizingMaskIntoConstraints = false

        // 软件卡片网格（双列）
        let cardContainer = NSView()
        cardContainer.translatesAutoresizingMaskIntoConstraints = false

        // 构建卡片列表：已有软件 + 占位卡片
        var cardList: [(card: SoftwareCardView, searchText: String)] = []
        for guide in guides {
            let card = SoftwareCardView(guide: guide)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.onCardClick = { [weak self] in self?.showDetail(guide: guide) }
            cardList.append((card, guide.name.lowercased()))
        }
        // 占位卡片
        let placeholders = ["Altium Designer", "KiCad", "VS Code", "更多软件…"]
        for name in placeholders {
            let card = SoftwareCardView(placeholderTitle: name)
            card.translatesAutoresizingMaskIntoConstraints = false
            cardList.append((card, name.lowercased()))
        }

        // 双列网格布局
        let columnSpacing: CGFloat = 14
        let rowSpacing: CGFloat = 14
        let leftCol = NSStackView()
        leftCol.orientation = .vertical
        leftCol.spacing = rowSpacing
        leftCol.translatesAutoresizingMaskIntoConstraints = false
        let rightCol = NSStackView()
        rightCol.orientation = .vertical
        rightCol.spacing = rowSpacing
        rightCol.translatesAutoresizingMaskIntoConstraints = false

        for (i, item) in cardList.enumerated() {
            if i % 2 == 0 {
                leftCol.addArrangedSubview(item.card)
            } else {
                rightCol.addArrangedSubview(item.card)
            }
            item.card.widthAnchor.constraint(equalTo: (i % 2 == 0 ? leftCol : rightCol).widthAnchor).isActive = true
        }

        let rowStack = NSStackView(views: [leftCol, rightCol])
        rowStack.orientation = .horizontal
        rowStack.spacing = columnSpacing
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 20),
            rowStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -20),
            leftCol.widthAnchor.constraint(equalTo: rightCol.widthAnchor),
        ])

        objc_setAssociatedObject(self, "homeCardRefs", cardList.map { ($0.card, $0.searchText) }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(hotkeyRow)
        container.addSubview(search)
        container.addSubview(cardContainer)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            hotkeyRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            hotkeyRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            search.topAnchor.constraint(equalTo: hotkeyRow.bottomAnchor, constant: 14),
            search.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            search.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            cardContainer.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 16),
            cardContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
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

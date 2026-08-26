import Cocoa

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
            btn.isBordered = false  // 移除默认bezel边框，完全用layer控制外观
            btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            btn.focusRingType = .none  // 移除蓝色焦点环
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 6
            btn.layer?.masksToBounds = false
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
                // 常亮标签：淡蓝色背景+蓝色加粗文字，突出显示
                btn.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
                btn.contentTintColor = .controlAccentColor
                btn.font = NSFont.systemFont(ofSize: 12, weight: .bold)
                btn.layer?.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
                btn.layer?.shadowRadius = 4
                btn.layer?.shadowOffset = NSSize(width: 0, height: 0)
                btn.layer?.shadowOpacity = 0.5
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

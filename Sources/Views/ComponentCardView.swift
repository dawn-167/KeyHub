import Cocoa

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
        layer?.borderWidth = 0
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

        // SPICE指令发光层（用shadow实现光晕，不用border避免非Retina屏黑边）
        let glow = CALayer()
        glow.frame = bounds
        glow.cornerRadius = 14
        glow.shadowColor = NSColor.controlAccentColor.cgColor
        glow.shadowRadius = 8
        glow.shadowOpacity = 0
        glow.shadowOffset = NSSize(width: 0, height: 0)
        layer?.insertSublayer(glow, at: 1)
        glowLayers.append(glow)

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
        let baseKeycap: CGFloat = 15
        let baseName: CGFloat = 13
        let baseEn: CGFloat = 11
        let basePlus: CGFloat = 10
        var keycapSize = baseKeycap
        var nameSize = baseName
        var enSize = baseEn
        var plusSize = basePlus
        // 只缩小不放大：所有内容统一base大小，长内容缩小确保显示全
        if enName.count > 40 || cnName.count > 10 {
            // 特别长，缩小2号确保显示全
            keycapSize -= 2
            nameSize -= 2
            enSize -= 1
            plusSize -= 1
        } else if enName.count > 10 || cnName.count > 8 {
            // 较长，缩小1号确保在正方形中显示全
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
        // 确保键帽字体不小于9
        keycapSize = max(keycapSize, 9)
        plusSize = max(plusSize, 9)

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
        nameLabel.cell?.wraps = true
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
        enLabel.cell?.wraps = true
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
        for glow in glowLayers {
            glow.frame = bounds
            glow.cornerRadius = 14
        }
        // 字体大小固定（27寸副屏最清晰的大小），不随卡片大小变化
        // 手动布局：确保每个元素位置都是整数像素，避免子像素渲染模糊
        let cardW = bounds.width
        let cardH = bounds.height
        let spacing: CGFloat = 10
        let textWidth = cardW - 24
        // 设置preferredMaxLayoutWidth，sizeThatFits才能正确计算多行高度
        nameLabel.preferredMaxLayoutWidth = textWidth
        enLabel.preferredMaxLayoutWidth = textWidth
        // 计算各元素大小（取整）
        keyRow.layoutSubtreeIfNeeded()
        let keyRowSize = keyRow.fittingSize
        let keyRowW = round(min(keyRowSize.width, textWidth))
        let keyRowH = round(keyRowSize.height)
        let nameSize = nameLabel.sizeThatFits(NSSize(width: textWidth, height: .greatestFiniteMagnitude))
        let nameW = textWidth
        let nameH = round(nameSize.height)
        var enH: CGFloat = 0
        if !enLabel.isHidden {
            let enSize = enLabel.sizeThatFits(NSSize(width: textWidth, height: .greatestFiniteMagnitude))
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
        // 完全移除边框，只用shadow实现立体感
        layer?.borderWidth = 0
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

import Cocoa

// MARK: - 软件卡片（首页用，NSButton 子类确保点击可靠 + 立体感 + 悬停）

final class SoftwareCardView: NSButton {
    let guide: SoftwareGuide?
    let isPlaceholder: Bool
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var highlightLayer: CALayer?
    private var rainbowGlowLayer: CAGradientLayer?
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
        layer?.borderWidth = 0  // 完全移除边框，避免黑边bug
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

        // 彩虹发光层（背面五彩光，放在背景层下面，柔和光晕+呼吸效果）
        let rainbow = CAGradientLayer()
        rainbow.colors = [
            NSColor(red: 1.0, green: 0.75, blue: 0.75, alpha: 1.0).cgColor,
            NSColor(red: 1.0, green: 0.88, blue: 0.65, alpha: 1.0).cgColor,
            NSColor(red: 0.92, green: 1.0, blue: 0.75, alpha: 1.0).cgColor,
            NSColor(red: 0.75, green: 1.0, blue: 0.85, alpha: 1.0).cgColor,
            NSColor(red: 0.75, green: 0.92, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.85, green: 0.8, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 1.0, green: 0.75, blue: 0.75, alpha: 1.0).cgColor
        ]
        rainbow.startPoint = CGPoint(x: 0, y: 0)
        rainbow.endPoint = CGPoint(x: 1, y: 1)
        rainbow.cornerRadius = 22
        rainbow.opacity = 0
        // 高斯模糊：让彩虹层边缘自然过渡，没有硬边界
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(10, forKey: "inputRadius")
            rainbow.filters = [blur]
        }
        // 柔和光晕：大半径shadow模拟模糊发光
        rainbow.shadowColor = NSColor(red: 0.85, green: 0.78, blue: 1.0, alpha: 1.0).cgColor
        rainbow.shadowRadius = 18
        rainbow.shadowOpacity = 0.85
        rainbow.shadowOffset = NSSize(width: 0, height: 0)
        layer?.insertSublayer(rainbow, below: grad)
        rainbowGlowLayer = rainbow

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
            // 优先使用自定义图标（bundle中以软件名命名的png）
            let customIconName = guide?.name ?? ""
            if let customImage = NSImage(named: customIconName) {
                iconBg.layer?.backgroundColor = NSColor.clear.cgColor
                iconBg.layer?.shadowOpacity = 0
                iconView.image = customImage
                iconView.contentTintColor = nil
            } else {
                iconBg.layer?.backgroundColor = NSColor.systemBlue.cgColor
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .bold)
                let iconName = guide?.icon ?? "command"
                iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
                    ?? NSImage(systemSymbolName: "command", accessibilityDescription: nil)?.withSymbolConfiguration(config)
                iconView.contentTintColor = .white
            }
        }

        // 文字
        let nameText = isPlaceholder ? placeholderTitle : (guide?.name ?? "")
        let nameLabel = ClickThroughLabel(labelWithString: nameText)
        // 艺术字：优先用Impact字体，不存在则用系统粗体
        nameLabel.font = NSFont(name: "Impact", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .heavy)
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
        textStack.alignment = .centerX
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let vStack = NSStackView(views: [iconBg, textStack])
        vStack.orientation = .vertical
        vStack.alignment = .centerX
        vStack.spacing = 2
        vStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vStack)

        NSLayoutConstraint.activate([
            iconBg.widthAnchor.constraint(equalToConstant: 64),
            iconBg.heightAnchor.constraint(equalToConstant: 64),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            vStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            vStack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 6),
            vStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            vStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])
    }

    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
        highlightLayer?.frame = NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        // 彩虹发光层比卡片大一圈，从背面透出来
        rainbowGlowLayer?.frame = bounds.insetBy(dx: -10, dy: -10)
        // 字体和图标随卡片大小动态缩放（纵向布局）
        let w = bounds.width
        if w > 0 && abs(w - lastCardWidth) > 1 {
            lastCardWidth = w
            let scale = w / 160  // 基准宽度160pt（正方形卡片）
            let nameSize = round(max(14, min(22, 17 * scale)))
            let infoSize = round(max(9, min(13, 10 * scale)))
            let updatedSize = round(max(8, min(12, 9 * scale)))
            let iconSize = round(max(52, min(80, 64 * scale)))
            let iconInnerSize = round(max(36, min(60, 48 * scale)))
            nameLabel?.font = NSFont(name: "Impact", size: nameSize) ?? NSFont.systemFont(ofSize: nameSize, weight: .heavy)
            nameLabel?.alignment = .center
            infoLabel?.font = NSFont.systemFont(ofSize: infoSize, weight: .regular)
            infoLabel?.alignment = .center
            updatedLabel?.font = NSFont.systemFont(ofSize: updatedSize, weight: .regular)
            updatedLabel?.alignment = .center
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
        // 完全移除边框，避免黑边bug
        layer?.borderWidth = 0
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
            NSColor(white: 1.0, alpha: 1.0).cgColor,
            NSColor(white: 0.97, alpha: 1.0).cgColor
        ]
        // 彩虹发光效果（固定颜色+柔和光晕+呼吸脉冲）
        rainbowGlowLayer?.opacity = 0.5
        // 呼吸脉冲动画：opacity从0.4到0.6循环，模拟发光呼吸
        let pulseAnim = CABasicAnimation(keyPath: "opacity")
        pulseAnim.fromValue = 0.4
        pulseAnim.toValue = 0.6
        pulseAnim.duration = 2.0
        pulseAnim.autoreverses = true
        pulseAnim.repeatCount = .infinity
        pulseAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rainbowGlowLayer?.add(pulseAnim, forKey: "breathing")
        layer?.borderWidth = 0
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
        layer?.shadowRadius = 12
        layer?.shadowOffset = NSSize(width: 0, height: -4)
        highlightLayer?.backgroundColor = NSColor.white.withAlphaComponent(0.4).cgColor
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
        // 隐藏彩虹发光
        rainbowGlowLayer?.opacity = 0
        rainbowGlowLayer?.removeAnimation(forKey: "breathing")
        layer?.borderWidth = 0  // 完全移除边框
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

import Cocoa

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
        // 键帽不被压缩，确保文字完整显示
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
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

    func setTintColor(_ color: NSColor) {
        // 用传入颜色生成渐变：顶部亮30%，底部暗15%
        let light = color.blended(withFraction: 0.3, of: .white) ?? color
        let dark = color.blended(withFraction: 0.15, of: .black) ?? color
        gradientLayer.colors = [light.cgColor, dark.cgColor]
        layer?.borderColor = dark.withAlphaComponent(0.6).cgColor
        layer?.shadowColor = dark.withAlphaComponent(0.3).cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize {
        let font = NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
        let w = (label.stringValue as NSString).size(withAttributes: [.font: font]).width
        let h = max(22, currentFontSize * 1.7)
        return NSSize(width: max(ceil(w) + 14, 28), height: h)
    }
}

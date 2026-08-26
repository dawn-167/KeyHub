import Cocoa

// MARK: - 提示气泡

final class CalloutView: NSView {
    enum Kind { case warning, info, note }
    private let label: NSTextField
    private var lastWidth: CGFloat = 0
    private var gradientLayer: CAGradientLayer!
    private var highlightLayer: CALayer!

    init(text: String, kind: Kind = .note, accentColor: NSColor? = nil) {
        label = NSTextField(wrappingLabelWithString: text)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 0
        layer?.masksToBounds = false

        let accent: NSColor
        if let custom = accentColor {
            accent = custom
        } else {
            switch kind {
            case .warning: accent = .systemOrange
            case .info:    accent = .systemBlue
            case .note:    accent = .systemGray
            }
        }

        // 渐变背景（上浅下深，立体感）
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            accent.withAlphaComponent(0.10).cgColor,
            accent.withAlphaComponent(0.06).cgColor
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        gradientLayer.cornerRadius = 12
        layer?.addSublayer(gradientLayer)

        // 顶部高光
        highlightLayer = CALayer()
        highlightLayer.backgroundColor = NSColor.white.withAlphaComponent(0.4).cgColor
        highlightLayer.cornerRadius = 12
        layer?.addSublayer(highlightLayer)

        // 外阴影（立体感）
        layer?.shadowColor = accent.withAlphaComponent(0.15).cgColor
        layer?.shadowRadius = 6
        layer?.shadowOpacity = 0.8
        layer?.shadowOffset = NSSize(width: 0, height: 2)

        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = accent.cgColor
        bar.layer?.cornerRadius = 2
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)

        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            bar.widthAnchor.constraint(equalToConstant: 4),
            label.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
        highlightLayer?.frame = NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        let w = bounds.width
        if w > 0 && abs(w - lastWidth) > 1 {
            lastWidth = w
            // 字体随宽度动态缩放（基准宽度448pt，基准字号13pt）
            let fontSize = max(12, min(18, w * 0.029))
            label.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

import Cocoa

// MARK: - 透传点击的 Label（不拦截鼠标事件）

final class ClickThroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - 渐变背景框（立体感）

final class GradientBoxView: NSView {
    private let gradientLayer = CAGradientLayer()
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = false
        gradientLayer.colors = [
            NSColor(white: 0.985, alpha: 1.0).cgColor,
            NSColor(white: 0.955, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        gradientLayer.cornerRadius = 14
        layer?.addSublayer(gradientLayer)
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.1).cgColor
        layer?.shadowRadius = 8
        layer?.shadowOpacity = 0.8
        layer?.shadowOffset = NSSize(width: 0, height: 2)
        translatesAutoresizingMaskIntoConstraints = false
    }
    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 立体分隔线（上阴影+下高光，模拟凸起）

final class SeparatorView: NSView {
    private let shadowLine = CALayer()
    private let highlightLine = CALayer()
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        // 上面深色线（阴影）
        shadowLine.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
        layer?.addSublayer(shadowLine)
        // 下面浅色线（高光）
        highlightLine.backgroundColor = NSColor.white.withAlphaComponent(0.8).cgColor
        layer?.addSublayer(highlightLine)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 2).isActive = true
    }
    override func layout() {
        super.layout()
        shadowLine.frame = NSRect(x: 0, y: 1, width: bounds.width, height: 0.5)
        highlightLine.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 0.5)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 手型光标按钮

final class HandCursorButton: NSButton {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - 翻转视图（NSScrollView 的 documentView 需要 flipped 坐标，否则内容从底部开始）

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

import Cocoa

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

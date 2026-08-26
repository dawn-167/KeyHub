import Cocoa

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

    // 判断卡片是否需要跨两列（基于实际内容尺寸精确计算）
    private func shouldSpan(_ card: ComponentCardView) -> Bool {
        let cw = cardWidth(for: bounds.width)
        let hPadding: CGFloat = 24
        let topMargin: CGFloat = 8
        let elementSpacing: CGFloat = 10
        let contentWidth = cw - hPadding
        let contentHeight = cw - topMargin * 2

        let desc = card.item.desc
        var cnName = desc
        var enName = ""
        if let lp = desc.lastIndex(of: "（"), let rp = desc.lastIndex(of: "）"), lp < rp {
            cnName = String(desc[..<lp]).trimmingCharacters(in: .whitespaces)
            enName = String(desc[desc.index(after: lp)..<rp]).trimmingCharacters(in: .whitespaces)
        }
        let comboCount = card.item.combos.first?.count ?? 0

        // 计算实际字体大小（与ComponentCardView一致：只缩小不放大）
        var keycapSize: CGFloat = 14
        var nameSize: CGFloat = 12
        var enSize: CGFloat = 11
        var plusSize: CGFloat = 10
        if enName.count > 40 || cnName.count > 10 {
            keycapSize -= 2; nameSize -= 2; enSize -= 1; plusSize -= 1
        } else if enName.count > 10 || cnName.count > 8 {
            keycapSize -= 1; nameSize -= 1; enSize -= 1; plusSize -= 1
        }
        if comboCount >= 3 { keycapSize -= 3; plusSize -= 2 }
        else if comboCount >= 2 { keycapSize -= 2; plusSize -= 1 }
        keycapSize = max(keycapSize, 9)
        plusSize = max(plusSize, 9)

        // 计算keyRow宽度
        let keycapFont = NSFont.systemFont(ofSize: keycapSize, weight: .semibold)
        let plusFont = NSFont.systemFont(ofSize: plusSize, weight: .semibold)
        var keyRowWidth: CGFloat = 0
        if let combo = card.item.combos.first {
            for (i, key) in combo.enumerated() {
                let tw = (key as NSString).size(withAttributes: [.font: keycapFont]).width
                keyRowWidth += max(ceil(tw) + 14, 28)
                if i < combo.count - 1 {
                    let pw = ("+" as NSString).size(withAttributes: [.font: plusFont]).width
                    keyRowWidth += pw + 2
                }
            }
        }
        // 键帽宽度超过内容宽度，必须跨列
        if keyRowWidth > contentWidth { return true }

        // 计算keyRow高度
        let keyRowHeight = max(22, keycapSize * 1.7)

        // 计算功能名高度
        let nameFont = NSFont.systemFont(ofSize: nameSize, weight: .semibold)
        let nameRect = (cnName as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: nameFont])
        let nameHeight = ceil(nameRect.height)
        // 计算中文行数，超过2行则跨列
        let nameSingleLineHeight = nameSize * 1.25
        let nameLineCount = Int(ceil(nameHeight / max(nameSingleLineHeight, 1)))
        if nameLineCount > 2 { return true }

        // 计算英文名高度
        var enHeight: CGFloat = 0
        var enLineCount: Int = 0
        if !enName.isEmpty {
            let enFont = NSFont.systemFont(ofSize: enSize, weight: .regular)
            let enRect = (enName as NSString).boundingRect(
                with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: enFont])
            enHeight = ceil(enRect.height)
            // 计算英文行数，超过2行则跨列
            let singleLineHeight = enSize * 1.25
            enLineCount = Int(ceil(enHeight / max(singleLineHeight, 1)))
        }

        // 英文部分超过两行，跨列
        if enLineCount > 2 { return true }

        // 中文+英文总行数>=3，跨列（避免单列太挤）
        if nameLineCount + enLineCount >= 3 { return true }

        // 总高度
        let totalHeight = keyRowHeight + elementSpacing + nameHeight + (enHeight > 0 ? elementSpacing + enHeight : 0)
        return totalHeight > contentHeight
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

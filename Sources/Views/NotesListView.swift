import Cocoa

// MARK: - 特别注意事项列表（大框+序号+立体分隔线）

final class NotesListView: NSView {
    private let gradientLayer = CAGradientLayer()

    init(notes: [String]) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = false

        // 渐变背景
        gradientLayer.colors = [
            NSColor(white: 0.98, alpha: 1.0).cgColor,
            NSColor(white: 0.95, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        gradientLayer.cornerRadius = 14
        layer?.addSublayer(gradientLayer)

        // 外阴影
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.12).cgColor
        layer?.shadowRadius = 10
        layer?.shadowOpacity = 0.9
        layer?.shadowOffset = NSSize(width: 0, height: 3)

        // 内容栈
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for (idx, note) in notes.enumerated() {
            if idx > 0 {
                let sep = SeparatorView()
                stack.addArrangedSubview(sep)
                sep.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 18).isActive = true
                sep.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -18).isActive = true
            }

            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            row.translatesAutoresizingMaskIntoConstraints = false

            // 键帽序号（橙色，与快捷键的浅灰色键帽区分）
            let keycap = KeycapView(key: "\(idx + 1)")
            keycap.setFontSize(14)
            keycap.setTintColor(.systemOrange)
            keycap.translatesAutoresizingMaskIntoConstraints = false
            keycap.widthAnchor.constraint(equalToConstant: 30).isActive = true
            keycap.heightAnchor.constraint(equalToConstant: 30).isActive = true
            row.addArrangedSubview(keycap)

            // 文字
            let label = NSTextField(wrappingLabelWithString: note)
            label.font = NSFont.systemFont(ofSize: 13.5, weight: .regular)
            label.textColor = .labelColor
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            row.addArrangedSubview(label)

            stack.addArrangedSubview(row)
            row.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 18).isActive = true
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -18).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])

        translatesAutoresizingMaskIntoConstraints = false
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }

    required init?(coder: NSCoder) { fatalError() }
}

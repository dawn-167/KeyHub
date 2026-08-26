import Cocoa
import Carbon.HIToolbox

// MARK: - 应用主体
// KeyHub - Nexus 工具类成员

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var guides: [SoftwareGuide] = []
    private var containerView: NSView?

    // 详情页状态
    private var currentGuide: SoftwareGuide?
    private var detailSearchField: NSSearchField?
    private var sectionTabs: SectionTabView?
    private var detailResultLabel: NSTextField?
    private var detailNoResults: NSView?
    private var detailScrollView: NSScrollView?
    private var detailContentStack: NSStackView?
    private var sectionContainers: [NSView] = []
    private var rowRefs: [(view: NSView, sectionIndex: Int, searchText: String)] = []
    private var selectedSection: Int = -1
    private var scrollObserver: NSObjectProtocol?
    private var hoverUpdateTimer: Timer?

    private let sectionColors: [NSColor] = [
        // 蓝、紫、绿、橙、红、青、靛蓝、粉、棕、薄荷绿、深青 — 11种区分度高的颜色
        NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1.0),
        NSColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1.0),
        NSColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0),
        NSColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0),
        NSColor(red: 0.353, green: 0.784, blue: 0.980, alpha: 1.0),
        NSColor(red: 0.345, green: 0.337, blue: 0.839, alpha: 1.0),
        NSColor(red: 1.0, green: 0.176, blue: 0.333, alpha: 1.0),
        NSColor(red: 0.635, green: 0.518, blue: 0.369, alpha: 1.0),
        NSColor(red: 0.0, green: 0.776, blue: 0.745, alpha: 1.0),
        NSColor(red: 0.196, green: 0.678, blue: 0.902, alpha: 1.0)
    ]
    private let warningColor = NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // 特别注意事项：黄色

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadAllGuides()
        setupStatusItem()
        setupWindow()
        // 使用 Nexus 共享热键管理
        NXHotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(controlKey) | UInt32(optionKey),
            signature: OSType(0x4B52), // "KR"
            onHotKey: { [weak self] in self?.toggleWindow() }
        )
        showHome()
        showWindow()
        // 延迟再次显示，确保窗口可见
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showWindow()
        }

        // 全局鼠标移动+滚轮监听：修复快速滑动/滚轮滚动时多个卡片被点亮无法熄灭的问题
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel]) { [weak self] event in
            self?.updateAllCardHoverStates()
            return event
        }

        // 定期更新悬停状态（80ms），确保滚轮滚动时悬停状态正确更新
        // 必须添加到 common runloop mode，否则滚轮滚动时（event tracking mode）Timer 不触发
        hoverUpdateTimer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateAllCardHoverStates()
        }
        if let timer = hoverUpdateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc private func updateAllCardHoverStates() {
        guard let win = window else { return }
        let mouseLoc = win.mouseLocationOutsideOfEventStream
        for ref in rowRefs {
            if let card = ref.view as? ComponentCardView {
                // 直接在窗口坐标和卡片坐标间转换，更可靠
                let cardPoint = card.convert(mouseLoc, from: nil)
                let mouseInCard = card.bounds.contains(cardPoint)
                card.applyHoverState(mouseInCard)
            }
        }
    }

    // 双击已运行的 app 时重新显示窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NXHotKeyManager.unregister()
    }

    // MARK: URL Scheme 跨应用唤起

    /// 处理其他 Nexus 应用通过 URL Scheme 唤起本应用
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let result = NXURLScheme.parse(url) else { continue }
            // 无论什么 action，先显示窗口
            showWindow()
            // 根据 action 执行后续操作
            switch result.action {
            case "search":
                if let q = result.params["q"] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.detailSearchField?.stringValue = q
                        self?.detailSearchChanged(self?.detailSearchField ?? NSSearchField())
                    }
                }
            case "open":
                if let guideName = result.params["guide"]?.lowercased() {
                    if let guide = guides.first(where: { $0.name.lowercased() == guideName }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.showDetail(guide: guide)
                        }
                    }
                }
            default:
                break // 仅显示窗口
            }
        }
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
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let img = NSImage(systemSymbolName: "book.closed", accessibilityDescription: "KeyHub 快捷键手册")?.withSymbolConfiguration(config)
            img?.isTemplate = true
            button.image = img
            button.imagePosition = .imageOnly
        }
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "显示 / 隐藏（⌃⌥K）", action: #selector(toggleWindow), keyEquivalent: "")
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
        // Nexus 元宇宙应用子菜单
        let dvMenu = makeNexusAppsMenu()
        let dvItem = NSMenuItem(title: "Nexus 应用", action: nil, keyEquivalent: "")
        dvItem.submenu = dvMenu
        menu.addItem(dvItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    // MARK: Nexus 跨应用

    /// 构建 Nexus 应用子菜单（动态检测已安装的应用）
    private func makeNexusAppsMenu() -> NSMenu {
        let menu = NSMenu(title: "Nexus 应用")

        // 打开元宇宙中心 Hub
        let hubItem = NSMenuItem(title: "Nexus Hub（元宇宙中心）", action: #selector(openNexusApp(_:)), keyEquivalent: "")
        hubItem.target = self
        hubItem.representedObject = "hub"
        hubItem.isEnabled = NXURLScheme.isAppInstalled(appId: "hub")
        if !hubItem.isEnabled {
            hubItem.title = "Nexus Hub（未安装）"
        }
        menu.addItem(hubItem)
        menu.addItem(.separator())

        // 已知的 Nexus 应用列表（未来可从配置文件读取）
        let knownApps: [(id: String, name: String, category: String)] = [
            ("keyhub", "KeyHub", "tool"),
            // 未来新增应用在此注册
        ]
        for app in knownApps {
            if app.id == "keyhub" { continue } // 跳过自己
            let item = NSMenuItem(title: app.name, action: #selector(openNexusApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app.id
            item.isEnabled = NXURLScheme.isAppInstalled(appId: app.id)
            if !item.isEnabled {
                item.title = "\(app.name)（未安装）"
            }
            menu.addItem(item)
        }

        if menu.items.count <= 2 {
            // 没有其他已安装应用时显示提示
            let hint = NSMenuItem(title: "暂无其他已安装应用", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        return menu
    }

    @objc private func openNexusApp(_ sender: NSMenuItem) {
        guard let appId = sender.representedObject as? String else { return }
        NXURLScheme.openApp(appId: appId)
    }

    // MARK: 窗口

    private func setupWindow() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 690),
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = "KeyHub"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.titlebarSeparatorStyle = .none
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.acceptsMouseMovedEvents = true
        // 宽度固定480，高度可纵向拉升（400 ~ 3000）
        win.minSize = NSSize(width: 480, height: 400)
        win.maxSize = NSSize(width: 480, height: 3000)
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

        // 淡绿色叠加层（正确设置frame）
        let greenTint = NSView(frame: vibrancy.bounds)
        greenTint.wantsLayer = true
        greenTint.layer?.backgroundColor = NSColor(red: 0.75, green: 0.95, blue: 0.80, alpha: 0.15).cgColor
        greenTint.autoresizingMask = [.width, .height]
        vibrancy.addSubview(greenTint)

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

        // 标题（加阴影效果，更有质感）
        let titleLabel = NSTextField(labelWithString: "KeyHub")
        titleLabel.font = NSFont(name: "Impact", size: 30) ?? NSFont.systemFont(ofSize: 30, weight: .heavy)
        titleLabel.textColor = .labelColor
        titleLabel.shadow = NSShadow()
        titleLabel.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.15)
        titleLabel.shadow?.shadowOffset = NSSize(width: 0, height: -1)
        titleLabel.shadow?.shadowBlurRadius = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 副标题（带装饰图标）
        let subtitleRow = NSStackView()
        subtitleRow.orientation = .horizontal
        subtitleRow.alignment = .centerY
        subtitleRow.spacing = 6
        subtitleRow.translatesAutoresizingMaskIntoConstraints = false

        let sparkleIcon = NSImageView()
        let sparkleConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        sparkleIcon.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?.withSymbolConfiguration(sparkleConfig)
        sparkleIcon.contentTintColor = .systemOrange
        sparkleIcon.translatesAutoresizingMaskIntoConstraints = false
        subtitleRow.addArrangedSubview(sparkleIcon)

        let subtitleLabel = NSTextField(labelWithString: "多软件快捷键速查")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleRow.addArrangedSubview(subtitleLabel)

        // 唤出指令提示（键帽样式）
        let hotkeyRow = NSStackView()
        hotkeyRow.orientation = .horizontal
        hotkeyRow.alignment = .centerY
        hotkeyRow.spacing = 4
        hotkeyRow.translatesAutoresizingMaskIntoConstraints = false

        let hotkeyLabel = NSTextField(labelWithString: "唤出/隐藏：")
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

        let kKey = KeycapView(key: "K")
        kKey.translatesAutoresizingMaskIntoConstraints = false
        hotkeyRow.addArrangedSubview(kKey)

        // 软件卡片列表：已有软件 + 占位卡片
        var cardList: [SoftwareCardView] = []
        for guide in guides {
            let card = SoftwareCardView(guide: guide)
            card.onCardClick = { [weak self] in self?.showDetail(guide: guide) }
            cardList.append(card)
        }
        // 占位卡片
        let placeholders = ["Altium Designer", "KiCad", "VS Code", "更多软件…", "敬请期待", "敬请期待"]
        for name in placeholders {
            let card = SoftwareCardView(placeholderTitle: name)
            cardList.append(card)
        }

        // 3列等宽正方形网格（与详情页风格一致）
        let gridView = HomeSoftwareGridView(cards: cardList)
        gridView.translatesAutoresizingMaskIntoConstraints = false

        // 滚动视图（内容超出窗口时可滚动）
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let docView = FlippedView()
        docView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = docView

        docView.addSubview(titleLabel)
        docView.addSubview(subtitleRow)
        docView.addSubview(hotkeyRow)
        docView.addSubview(gridView)

        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            docView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            titleLabel.topAnchor.constraint(equalTo: docView.topAnchor, constant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            subtitleRow.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleRow.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            hotkeyRow.topAnchor.constraint(equalTo: subtitleRow.bottomAnchor, constant: 10),
            hotkeyRow.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            gridView.topAnchor.constraint(equalTo: hotkeyRow.bottomAnchor, constant: 20),
            gridView.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 16),
            gridView.trailingAnchor.constraint(equalTo: docView.trailingAnchor, constant: -16),
            gridView.bottomAnchor.constraint(equalTo: docView.bottomAnchor, constant: -20),
        ])
        // 滚动到顶部
        DispatchQueue.main.async {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
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
        let backBtn = HandCursorButton(title: "‹ 首页", target: self, action: #selector(goHome))
        backBtn.bezelStyle = .inline
        backBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        backBtn.contentTintColor = .controlAccentColor
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        // 软件名 + 版本（和首页卡片风格一致：图标+Impact艺术字+淡灰色版本信息）
        // 图标（和首页卡片一样的逻辑：优先用bundle中以软件名命名的png）
        let iconBg = NSView()
        iconBg.wantsLayer = true
        iconBg.layer?.cornerRadius = 12
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let customIconName = guide.name
        if let customImage = NSImage(named: customIconName) {
            iconBg.layer?.backgroundColor = NSColor.clear.cgColor
            iconBg.layer?.shadowOpacity = 0
            iconView.image = customImage
            iconView.contentTintColor = nil
        } else {
            iconBg.layer?.backgroundColor = NSColor.systemBlue.cgColor
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            iconView.image = NSImage(systemSymbolName: guide.icon, accessibilityDescription: nil)?.withSymbolConfiguration(config)
                ?? NSImage(systemSymbolName: "command", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            iconView.contentTintColor = .white
        }
        iconBg.addSubview(iconView)

        // 软件名（Impact艺术字，和首页卡片一致）
        let nameLabel = NSTextField(labelWithString: guide.name)
        nameLabel.font = NSFont(name: "Impact", size: 20) ?? NSFont.systemFont(ofSize: 20, weight: .heavy)
        nameLabel.textColor = .labelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // 版本信息（淡灰色，和首页卡片一致）
        let versionLabel = NSTextField(labelWithString: "v\(guide.version) · 适配 \(guide.minVersion)+ · 更新 \(guide.lastUpdated)")
        versionLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        // 文字垂直stack
        let textStack = NSStackView(views: [nameLabel, versionLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // 图标+文字水平stack
        let titleStack = NSStackView(views: [iconBg, textStack])
        titleStack.orientation = .horizontal
        titleStack.alignment = .centerY
        titleStack.spacing = 10
        titleStack.translatesAutoresizingMaskIntoConstraints = false

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
        detailScrollView = scroll

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        detailContentStack = contentStack

        for (i, section) in guide.sections.enumerated() {
            let container = NSStackView()
            container.orientation = .vertical
            container.alignment = .leading
            container.spacing = 8
            container.translatesAutoresizingMaskIntoConstraints = false
            sectionContainers.append(container)

            let color: NSColor
            if section.title.contains("注意") {
                color = warningColor  // 特别注意事项固定黄色
            } else {
                color = i < sectionColors.count ? sectionColors[i] : sectionColors[i % sectionColors.count]
            }
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

            if section.title.contains("注意") {
                // 特别注意事项：大框+序号，序号黄色
                let notesView = NotesListView(notes: section.notes, accentColor: warningColor)
                container.addArrangedSubview(notesView)
                notesView.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
                rowRefs.append((view: notesView, sectionIndex: i, searchText: section.notes.joined(separator: " ").lowercased()))
            } else if !section.notes.isEmpty {
                // 普通分区：所有 note 合并为一个大框+序号，序号颜色跟随分区主题色
                let cleanedNotes = section.notes.map { note -> String in
                    // 去掉内容项前面的 "- " 前缀
                    note.hasPrefix("- ") ? String(note.dropFirst(2)) : note
                }
                let notesView = NotesListView(notes: cleanedNotes, accentColor: color)
                notesView.translatesAutoresizingMaskIntoConstraints = false
                container.addArrangedSubview(notesView)
                notesView.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
                rowRefs.append((view: notesView, sectionIndex: i, searchText: cleanedNotes.joined(separator: " ").lowercased()))
            }

            contentStack.addArrangedSubview(container)
            container.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }

        // 底部
        let footer = NSTextField(labelWithString: "⌃⌥K 切换显示 · 菜单栏图标可返回首页 / 退出")
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
        // 监听滚动视图内容偏移变化，修复滚轮滚动时多个卡片被点亮无法熄灭的bug
        if let obs = scrollObserver { NotificationCenter.default.removeObserver(obs) }
        scroll.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in
            self?.updateAllCardHoverStates()
        }
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        container.addSubview(backBtn)
        container.addSubview(titleStack)
        container.addSubview(search)
        container.addSubview(sectionTab)
        container.addSubview(result)
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            backBtn.topAnchor.constraint(equalTo: container.topAnchor, constant: 36),
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            backBtn.heightAnchor.constraint(equalToConstant: 24),

            // 标题区域（图标+文字）
            titleStack.topAnchor.constraint(equalTo: backBtn.bottomAnchor, constant: 8),
            titleStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            search.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 10),
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

        // 递归查找所有 ComponentGridView 并强制重新布局（搜索过滤后可见卡片变化）
        func findAndRelayout(_ view: NSView) {
            if let grid = view as? ComponentGridView {
                grid.needsLayout = true
                grid.layoutSubtreeIfNeeded()
            }
            for sub in view.subviews {
                findAndRelayout(sub)
            }
        }
        for container in sectionContainers {
            findAndRelayout(container)
        }
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
        grid.notifyCardsAdded()
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
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

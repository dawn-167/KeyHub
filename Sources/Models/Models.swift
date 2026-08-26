import Cocoa

// MARK: - 数据模型

/// 单个快捷键/指令条目
struct ShortcutItem {
    /// 按键组合，支持多组替代键（如 ["Ctrl+Z", "Ctrl+Shift+Z"]）
    let combos: [[String]]
    /// 功能描述
    let desc: String
    /// 详细使用说明（SPICE 指令等）
    var detail: String = ""
}

/// 一个分区（如"放置元件"、"编辑操作"）
struct SectionData {
    let title: String
    var items: [ShortcutItem] = []
    var notes: [String] = []
}

/// 一个软件的完整指南
struct SoftwareGuide {
    let name: String
    let version: String
    let icon: String
    let lastUpdated: String
    let minVersion: String
    let sections: [SectionData]
    var totalShortcuts: Int { sections.reduce(0) { $0 + $1.items.count } }
}

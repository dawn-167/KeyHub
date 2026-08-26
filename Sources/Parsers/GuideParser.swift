import Cocoa

// MARK: - 指南解析

/// 解析 guides/*.md 文件为 SoftwareGuide 数据结构
enum GuideParser {
    static func load(from text: String) -> SoftwareGuide {
        var name = "未知软件"
        var version = "—"
        var icon = "command"
        var lastUpdated = "—"
        var minVersion = "—"
        var sections: [SectionData] = []
        var current: SectionData?
        var inFrontmatter = false
        var frontmatterDone = false
        var currentDetailItem: Int? = nil
        var inOptionsTable = false

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)

            // 解析 YAML frontmatter
            if line == "---" {
                if !frontmatterDone {
                    inFrontmatter.toggle()
                    if !inFrontmatter { frontmatterDone = true }
                }
                continue
            }
            if inFrontmatter {
                if let colonRange = line.range(of: ":") {
                    let key = String(line[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let value = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    switch key.lowercased() {
                    case "name": name = value
                    case "version": version = value
                    case "icon": icon = value
                    case "last_updated": lastUpdated = value
                    case "min_version": minVersion = value
                    default: break
                    }
                }
                continue
            }

            if line.isEmpty || line == "---" { continue }

            if line.hasPrefix("## ") {
                if let cur = current { sections.append(cur) }
                current = SectionData(title: String(line.dropFirst(3)))
                currentDetailItem = nil
                inOptionsTable = false
                continue
            }
            if line.hasPrefix("# ") {
                let t = String(line.dropFirst(2))
                if t.contains("注意") || t.contains("说明") {
                    if let cur = current { sections.append(cur) }
                    current = SectionData(title: t)
                    currentDetailItem = nil
                    inOptionsTable = false
                }
                continue
            }
            if line.hasPrefix("> ") {
                let t = strip(String(line.dropFirst(2)))
                current?.notes.append(t)
                continue
            }
            if line.hasPrefix("#### ") {
                // 指令详细说明子标题，如 "#### .TRAN — 瞬态分析"
                let title = String(line.dropFirst(5))
                if title.hasPrefix(".") {
                    // 提取指令名
                    let cmdName = title.components(separatedBy: " ")[0].components(separatedBy: "—")[0].trimmingCharacters(in: .whitespaces)
                    // 在当前 section 中查找匹配的 item
                    if let idx = current?.items.firstIndex(where: { $0.combos.first?.first == cmdName }) {
                        current?.items[idx].detail = ""
                        currentDetailItem = idx
                    }
                }
                continue
            }
            if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
                currentDetailItem = nil
            }
            if currentDetailItem != nil && !line.hasPrefix("|") && !line.hasPrefix("```") {
                // 累积详细说明文本，空行作为段落分隔
                if line.isEmpty {
                    if let cur = current, !cur.items[currentDetailItem!].detail.isEmpty {
                        var newCur = cur
                        newCur.items[currentDetailItem!].detail += "\n\n"
                        current = newCur
                    }
                } else {
                    let t = strip(line)
                    if !t.isEmpty, var cur = current {
                        let idx = currentDetailItem!
                        cur.items[idx].detail += (cur.items[idx].detail.isEmpty ? "" : "\n") + t
                        current = cur
                    }
                }
                continue
            }
            if line.hasPrefix("|") {
                guard let cells = tableCells(line), cells.count >= 2 else { continue }
                let keyCell = cells[0]
                // 跳过表头和分隔行
                if keyCell == "快捷键" || keyCell == "指令" || keyCell == "参数" || keyCell == "操作" ||
                    keyCell.allSatisfy({ $0 == "-" || $0 == ":" }) {
                    if keyCell == "参数" { inOptionsTable = true }
                    continue
                }
                if inOptionsTable { continue }  // 跳过 .OPTIONS 参数表
                let combos = parseCombo(keyCell)
                if combos.isEmpty { continue }
                var desc = cells[1].replacingOccurrences(of: "**", with: "")
                // 第三列：合并到功能描述（语法示例等）
                if cells.count >= 3 {
                    let third = cells[2].replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                    if !third.isEmpty {
                        let cleanThird = third.replacingOccurrences(of: "`", with: "")
                        desc = "\(desc)（\(cleanThird)）"
                    }
                }
                current?.items.append(ShortcutItem(combos: combos, desc: desc))
                continue
            }
            inOptionsTable = false  // 非表格行，重置参数表标记
            if let num = line.first, num.isNumber, line.contains(". ") {
                let parts = line.split(separator: ".", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    current?.notes.append(strip(parts[1].trimmingCharacters(in: .whitespaces)))
                }
                continue
            }
        }
        if let cur = current { sections.append(cur) }
        return SoftwareGuide(name: name, version: version, icon: icon,
                             lastUpdated: lastUpdated, minVersion: minVersion, sections: sections)
    }

    private static func tableCells(_ line: String) -> [String]? {
        var cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.first == "" { cells.removeFirst() }
        if cells.last == "" { cells.removeLast() }
        return cells.isEmpty ? nil : cells
    }

    private static func parseCombo(_ cell: String) -> [[String]] {
        let stripped = cell.replacingOccurrences(of: "**", with: "")
        let noAnno = stripped.replacingOccurrences(of: "（[^）]*）", with: "", options: .regularExpression)
        var result: [[String]] = []
        for part in noAnno.components(separatedBy: "/") {
            let keys = part.components(separatedBy: "+")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !keys.isEmpty { result.append(keys) }
        }
        return result
    }

    private static func strip(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
    }
}

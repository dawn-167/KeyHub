# Changelog

所有重要变更都记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.3.0] - 2026-08-26

### Nexus 元宇宙接入

- **接入 Nexus 规范**：项目正式成为 Nexus 软件元宇宙的工具类成员
- **Bundle ID 统一**：`com.keyref.app` → `com.nexus.tool.keyhub`
- **URL Scheme**：注册 `nexus-keyhub://`，支持跨应用唤起
- **新增 `nexus.json`**：元宇宙应用身份配置文件
- **新增 `Nexus/SPECIFICATION.md`**：元宇宙开发规范文档（命名/结构/共享组件/UI/构建/通信）
- **新增 `README.md`**：项目说明文档
- **共享基础设施层**：创建 `Sources/Common/`，引入 CommonKit 组件
  - `NXHotKeyManager` — 统一全局热键管理（替代原 HotKeyManager）
  - `NXWindowStyle` — 统一毛玻璃浮动窗口创建
  - `NXStatusItem` — 统一菜单栏项和菜单模板
  - `NXPixelUtils` — 像素对齐工具（frame 取整、contentsScale 同步）
  - `NXURLScheme` — 跨应用 URL Scheme 通信（打开/解析/检测安装）
  - `NXCommon` — 元宇宙元信息和应用分类枚举
- **跨应用唤起**：实现 Nexus 应用间互相打开
  - 注册 URL Scheme `nexus-keyhub://`，支持 `search`、`open` 等深度链接
  - 菜单栏新增"Nexus 应用"子菜单，可打开其他已安装应用
  - 支持 `nexus-keyhub://search?q=xxx` 唤起并搜索
  - 支持 `nexus-keyhub://open?guide=xxx` 唤起并打开指定指南
- **隐私保护**：清理所有文档和配置中的个人隐私信息（移除 author 字段等）
- **构建脚本升级**：`build.sh` 支持 `--clean`、`--no-sign` 参数，增加签名步骤
- **Info.plist 完善**：补充 CFBundleName、URL Types，修正 DisplayName

### 架构重构

- **代码模块化拆分**：将原 2911 行单文件 `main.swift` 拆分为按模块组织的多文件结构
  - `Sources/main.swift` — 应用入口
  - `Sources/App/AppDelegate.swift` — 应用主体
  - `Sources/Models/Models.swift` — 数据模型
  - `Sources/Parsers/GuideParser.swift` — Markdown 解析器
  - `Sources/Views/` — 10 个 UI 组件文件
  - `Sources/Common/` — 4 个共享组件文件

### 删除（无用代码清理）

- `steppedSize()` / `roundToEven()` — 从未调用
- `VersionBadge` 类 — 版本功能已移除，从未实例化
- `ShortcutCardView` 类 — 已被 ComponentCardView 替代
- `makeGrid()` / `searchText(of:)` — 从未调用
- `showNotesPage()` / `backToDetail()` — 从未调用
- `homeSearchChanged()` — 首页无搜索框
- `ShortcutItem.version` / `helpUrl` — 从未使用
- `Sources/App/HotKey.swift` — 迁移至 Common/NXHotKeyManager

### 修复

- `SectionTabView.alwaysHighlightTitles` 未设置的问题

### 数据模型简化

- `GuideParser` 移除版本列解析，第三列合并到功能描述

## [0.2.0] - 2026-08-25

### 新增

- 多软件架构：首页软件卡片网格 + 详情页两级导航
- LTspice 完整快捷键收录（原理图/符号/波形/网表 4 个编辑器）
- SPICE 指令参考（40+ 指令，20 个含详细说明）
- 全局热键 ⌃⌥L 唤出/隐藏
- 菜单栏常驻图标
- 实时搜索过滤
- 分区导航标签
- 注意事项独立展示

### 变更

- 键帽显示官方键名（Ctrl/Alt/Shift），不做 Mac 符号转换
- 所有快捷键卡片统一为 3 列正方形卡片布局
- SPICE 指令卡片点击弹出详细说明窗口

## [0.1.0] - 2026-08-24

### 新增

- LTspice 单软件原型
- 毛玻璃浮动窗口
- 双列网格卡片布局
- 搜索实时过滤

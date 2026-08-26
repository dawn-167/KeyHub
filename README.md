# KeyHub

> Nexus 元宇宙 · 工具类成员
> 多软件快捷键速查工具，全局热键一键唤出

## 简介

KeyHub 是一款 macOS 原生的多软件快捷键速查工具。通过全局热键 `⌃⌥L`（Control+Option+L）一键唤出浮动窗口，快速查阅目标软件的所有快捷键和指令。

目前支持 LTspice，后续可通过在 `guides/` 目录添加 Markdown 文件扩展更多软件。

## 功能特性

- 全局热键唤出，浮动窗口始终置顶
- 首页卡片式布局，支持多软件
- 按功能分区 tab 切换
- 实时搜索快捷键和功能描述
- SPICE 指令点击查看详细说明
- 毛玻璃窗口 + 立体卡片 UI

## 快速开始

### 编译运行

```bash
./build.sh          # 编译 + 同步资源 + 签名
open KeyHub.app     # 运行
```

### 构建参数

```bash
./build.sh --no-sign    # 只编译不签名
./build.sh --clean      # 清理后重新编译
```

## 添加新软件指南

1. 在 `guides/` 目录下创建 `软件名.md`
2. 按 Markdown 表格格式编写快捷键数据
3. 重新运行 `./build.sh`
4. 应用启动时自动加载，无需修改代码

## 项目结构

```
KeyHub/
├── Sources/            # 源代码（App/Models/Parsers/Views/Common）
├── guides/             # 快捷键数据（Markdown）
├── docs/               # 文档
│   ├── TECHNICAL_DOCUMENTATION.md  # 技术文档
│   └── ISSUES.md                    # 问题记录
├── KeyHub.app/         # 编译产物
├── build.sh            # 构建脚本
├── nexus.json          # Nexus 元宇宙配置
├── CHANGELOG.md        # 更新日志
└── README.md           # 本文件
```

## Nexus 元宇宙

KeyHub 是 Nexus 软件元宇宙的工具类成员。所有 Nexus 应用共享统一的品牌标识、技术基础设施和用户体验，可通过 URL Scheme 互相唤起。

- 应用配置：[nexus.json](nexus.json)
- Bundle ID：`com.nexus.tool.keyhub`
- URL Scheme：`nexus-keyhub://`
- 共享组件：`Sources/Common/`（NXHotKeyManager、NXURLScheme 等）

> Nexus 元宇宙开发规范文档单独保存，不在本项目内。

## 系统要求

- macOS 13.0+
- 无第三方依赖

## 许可证

内部项目

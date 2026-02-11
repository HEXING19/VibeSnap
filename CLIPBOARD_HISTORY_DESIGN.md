# VibeSnap 剪贴板历史追踪功能 - 设计文档

## 1. 功能概述

在 VibeSnap 截图工具中新增 **剪贴板历史追踪** 功能，参考 [OmniClip](https://github.com/nahid0-0/OmniClip) 的实现方式，实现自动监控系统剪贴板变化，记录文本和图片内容，并提供管理与快速粘贴能力。

### 核心特性
- 📋 **自动剪贴板历史追踪** - 实时监控系统剪贴板，自动记录文本和图片
- 🖼️ **截图自动检测** - 通过 `NSMetadataQuery` 检测系统截图并自动记录
- ⚡ **快速访问** - 通过菜单栏和全局快捷键 (⌘+Shift+V) 快速访问剪贴板历史
- 🔍 **预览与搜索** - 预览剪贴板内容，支持文本搜索
- 📌 **置顶功能** - 将常用条目置顶
- 🗑️ **条目管理** - 删除、清空操作
- 💾 **持久化存储** - 图片数据持久化到磁盘，跨应用重启保留

---

## 2. 架构设计

### 2.1 新增文件结构
```
VibeSnap/
├── Features/
│   └── Clipboard/                          # 新增模块
│       ├── Models/
│       │   └── ClipboardItem.swift          # 剪贴板条目数据模型
│       ├── ClipboardManager.swift           # 剪贴板监控管理器
│       ├── ClipboardHistoryPanel.swift      # 剪贴板历史浮动面板
│       ├── ClipboardItemRow.swift           # 条目行视图 (SwiftUI)
│       └── ClipboardPreviewPanel.swift      # 预览面板 (SwiftUI)
├── Core/
│   └── Managers/
│       └── (已有 HotkeyManager.swift)       # 需新增快捷键
```

### 2.2 修改文件
- `StatusBarController.swift` - 添加 "Clipboard History" 菜单项
- `AppDelegate.swift` - 初始化 ClipboardManager，设置快捷键回调
- `HotkeyManager.swift` - 新增 ⌘+Shift+V 快捷键
- `SettingsView.swift` - 新增剪贴板相关设置

---

## 3. 数据模型设计

### 3.1 ClipboardItem (剪贴板条目)

```swift
// 文本类型
struct TextClipItem {
    let id: UUID
    let createdAt: Date
    var isPinned: Bool
    let text: String
}

// 图片类型
struct ImageClipItem {
    let id: UUID
    let createdAt: Date
    var isPinned: Bool
    let imageData: Data
    let width: Int
    let height: Int
}

// 统一枚举
enum ClipboardItemType: Identifiable {
    case text(TextClipItem)
    case image(ImageClipItem)
}
```

### 3.2 容量策略 (环形缓冲区 + 置顶保护)
- 最大总条目: **30**
- 最大未置顶条目: **25**
- 最大置顶条目: **5**
- 超出限制时自动移除最旧的未置顶条目

---

## 4. 核心组件设计

### 4.1 ClipboardManager (剪贴板监控器)
- **轮询机制**: 每 0.5s 检查 `NSPasteboard.general.changeCount`
- **去重**: 连续相同内容不重复记录
- **类型识别**: 优先级 图片文件URL > TIFF/PNG > 纯文本
- **忽略机制**: 自身复制操作不产生新记录
- **截图监控**: 集成 `NSMetadataQuery` 监控系统截图(可在设置中开关)

### 4.2 ClipboardHistoryPanel (历史面板)
- 浮动 NSPanel，700×500 尺寸
- 左右分栏: 列表 | 预览
- 顶部搜索栏
- 底部工具栏 (条目计数、清空操作)
- 快捷键 ⌘+Shift+V 唤出

### 4.3 ClipboardItemRow (条目行)
- 单行显示: 文本预览(截断到2行) / 图片缩略图 + 尺寸信息
- 悬停显示复制按钮
- 置顶标识图标
- 时间戳显示(可配置)

### 4.4 ClipboardPreviewPanel (预览面板)
- 顶部: 置顶/删除操作按钮
- 中部: 完整内容预览 (文本使用 NSTextView 虚拟化，图片可缩放)
- 底部: 复制按钮 + 元数据信息

---

## 5. 集成方案

### 5.1 菜单栏集成
在 StatusBarController 的菜单中，History 项下方新增:
```
Clipboard History   ⇧⌘V
```

### 5.2 快捷键集成
在 HotkeyManager 中注册:
- `⌘+Shift+V` → 打开/关闭剪贴板历史面板

### 5.3 AppDelegate 集成
- `applicationDidFinishLaunching` 中初始化 `ClipboardManager.shared`
- 设置快捷键回调
- 注册 `showClipboardHistory` 通知监听

### 5.4 设置集成
在 SettingsView 中新增 "Clipboard" 标签页:
- 开关: 启用剪贴板监控
- 开关: 自动捕获系统截图
- 开关: 显示时间戳
- 选项: 最大记录条数 (10/20/30/50)

---

## 6. 实现计划

| 步骤 | 文件 | 描述 |
|------|------|------|
| 1 | `ClipboardItem.swift` | 创建数据模型 |
| 2 | `ClipboardManager.swift` | 实现监控核心 |
| 3 | `ClipboardItemRow.swift` | 条目行 SwiftUI 视图 |
| 4 | `ClipboardPreviewPanel.swift` | 预览面板 SwiftUI 视图 |
| 5 | `ClipboardHistoryPanel.swift` | 浮动面板窗口控制器 |
| 6 | `StatusBarController.swift` | 菜单项集成 |
| 7 | `HotkeyManager.swift` | 快捷键集成 |
| 8 | `AppDelegate.swift` | 初始化集成 |
| 9 | `SettingsView.swift` | 设置界面集成 |

# 标注工具UI重构完成

## 架构变更

### 之前的架构
- **单一窗口**：`AnnotationToolbar` 窗口包含所有内容
  - 深色背景 (white: 0.08)
  - 工具栏在窗口内部顶部
  - 属性面板在工具栏下方
  - 画布在中间
  - 操作按钮在底部

### 现在的架构 ✅
- **主窗口** (`AnnotationToolbar`)：
  - 无边框 (borderless)
  - 透明背景
  - 只包含画布和底部操作按钮
  - 浅色背景 (white: 0.95, alpha: 0.98)
  - 圆角 8px

- **浮动工具栏窗口** (`FloatingToolbarWindow`)：
  - 独立的 NSPanel
  - 毛玻璃效果 (NSVisualEffectView with .hudWindow material)
  - 圆角 12px
  - 宽度 580px，高度 48px
  - 包含 10 个工具图标 + 颜色选择器 + 撤销/重做按钮
  - 自动跟随主窗口移动

- **浮动属性面板窗口** (`FloatingPropertiesWindow`)：
  - 独立的 NSPanel
  - 毛玻璃效果 (NSVisualEffectView with .hudWindow material)
  - 圆角 12px
  - 宽度 420px，高度 44px
  - 只显示图标和滑块，无文字标签
  - 根据选择的工具动态显示相关控件
  - 自动跟随主窗口移动

## 新增文件

1. **FloatingToolbarWindow.swift**
   - `FloatingToolbarWindow`: 浮动工具栏窗口类
   - `AnnotationToolsView`: 工具栏内容视图
   - 包含所有 10 个标注工具的按钮
   - SF Symbols 图标匹配 macOS Preview 样式

2. **FloatingPropertiesWindow.swift**
   - `FloatingPropertiesWindow`: 浮动属性面板窗口类
   - `ToolPropertiesView`: 属性面板内容视图
   - 动态显示工具相关属性（线条粗细、不透明度、圆角、填充）

## 修改的文件

1. **AnnotationToolbar.swift**
   - 重构为简洁的主窗口
   - 管理两个浮动窗口的生命周期
   - 监听窗口移动事件，同步更新浮动窗口位置
   - `ActionButtonsBar` 添加回调支持

2. **CanvasView.swift**
   - 添加 `getFinalImage()` 方法

3. **FloatingToolbarWindow.swift** (新增)
   - 实现浮动工具栏

4. **FloatingPropertiesWindow.swift** (新增)
   - 实现浮动属性面板

## 视觉效果

### 工具栏
- ✅ 浅色半透明背景（毛玻璃效果）
- ✅ 圆角 12px
- ✅ 10 个工具图标，间距 8px
- ✅ 图标颜色：深灰色 (white: 0.25)
- ✅ 选中状态：浅蓝色背景 + 蓝色图标
- ✅ 分隔线分隔工具和控制按钮
- ✅ 颜色选择器
- ✅ 撤销/重做按钮

### 属性面板
- ✅ 浅色半透明背景（毛玻璃效果）
- ✅ 圆角 12px
- ✅ 只显示图标和滑块，无文字标签
- ✅ 颜色选择器在最左侧
- ✅ 分隔线分隔不同控件组
- ✅ 根据工具类型动态显示/隐藏控件

### 主窗口
- ✅ 无边框
- ✅ 浅色背景 (white: 0.95)
- ✅ 圆角 8px
- ✅ 只显示画布和底部操作按钮

## 工具列表

| # | 工具 | SF Symbol | 可调属性 |
|---|------|-----------|----------|
| 1 | 矩形 | `rectangle` | 线条粗细、不透明度、圆角、填充 |
| 2 | 椭圆 | `circle` | 线条粗细、不透明度、填充 |
| 3 | 直线 | `line.diagonal` | 线条粗细、不透明度 |
| 4 | 箭头 | `arrow.up.right` | 线条粗细、不透明度 |
| 5 | 自由绘制 | `scribble.variable` | 线条粗细、不透明度 |
| 6 | 标注气泡 | `text.bubble` | 不透明度 |
| 7 | 文字 | `textformat` | 不透明度 |
| 8 | 序号 | `1.circle` | 不透明度 |
| 9 | 马赛克 | `checkerboard.rectangle` | 不透明度 |
| 10 | 放大镜 | `magnifyingglass` | 不透明度 |

## 技术实现

### 浮动窗口跟随
```swift
// 监听主窗口移动
NotificationCenter.default.addObserver(
    self,
    selector: #selector(windowDidMove),
    name: NSWindow.didMoveNotification,
    object: self
)

// 更新浮动窗口位置
private func updateFloatingWindowPositions() {
    floatingToolbar?.positionRelativeTo(window: self, offset: CGPoint(x: 0, y: 20))
    floatingProperties?.positionRelativeTo(window: self, offset: CGPoint(x: 0, y: 80))
}
```

### 毛玻璃效果
```swift
let visualEffect = NSVisualEffectView(frame: contentView!.bounds)
visualEffect.material = .hudWindow
visualEffect.state = .active
visualEffect.blendingMode = .behindWindow
visualEffect.layer?.cornerRadius = 12
```

### 动画效果
```swift
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.3
    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
    self.animator().alphaValue = 1
    self.floatingToolbar?.animator().alphaValue = 1
    self.floatingProperties?.animator().alphaValue = 1
}
```

## 下一步

所有 10 个标注工具的基础框架已经完成。现在需要：

1. ✅ 矩形工具 - 已实现
2. ⚠️ 椭圆工具 - 需要完善
3. ⚠️ 直线工具 - 需要完善
4. ⚠️ 箭头工具 - 需要完善
5. ⚠️ 自由绘制工具 - 需要完善
6. ⚠️ 标注气泡工具 - 需要实现
7. ⚠️ 文字工具 - 需要完善
8. ⚠️ 序号工具 - 需要实现
9. ⚠️ 马赛克工具 - 需要实现
10. ⚠️ 放大镜工具 - 需要实现

每个工具都需要在 `CanvasView.swift` 中实现其绘制逻辑。

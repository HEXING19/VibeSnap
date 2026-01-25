VibeSnap 产品需求详细规格说明书 (PRD)-这是一个专门为macOS26开发的截图工具，专注截图，
1. 用户画像与核心场景目标用户：开发者、设计师、产品经理。他们对像素级精度有执念，厌恶等待，习惯快捷键操作。
核心场景：Bug 汇报：快速截取出错弹窗，标记红框，粘贴到 Jira/Slack。
UI 走查：测量 UI 元素间距，对比设计稿。资料留存：将某段代码或配置“钉”在屏幕上作为参考，同时在另一个窗口写代码。
2. 功能模块一：常驻菜单栏代理 (Menu Bar Agent)应用即服务（App as a Service）。VibeSnap 不会在 Dock 栏显示图标，仅在菜单栏驻留，最大化减少视觉干扰。
2.1 功能描述状态栏图标：设计一个极简的“取景框”风格图标。
下拉菜单：Capture Area (区域截图) - 快捷键 ⇧⌘1Capture Window (窗口截图) - 快捷键 ⇧⌘2Capture Fullscreen (全屏截图) - 快捷键 ⇧⌘3Settings (设置)Quit (退出)启动逻辑：首次启动时，静默检查“屏幕录制”权限。若未授权，弹出带有引导图的原生 NSAlert，引导用户跳转系统设置。
2.2 Vibe Coding 实施提示“让 AI 使用 LSUIElement 键值在 Info.plist 中隐藏 Dock 图标。使用 NSStatusBar 创建系统菜单。必须实现一个 PermissionsManager 单例，封装 CGPreflightScreenCaptureAccess 和 CGRequestScreenCaptureAccess 方法。”

3. 功能模块二：智能截图引擎 (The Snip Engine)这是复刻 1capture 体验的核心。
3.1 交互流程触发：用户按下全局快捷键（默认 ⇧⌘1）。冻结（Freeze）：屏幕画面瞬间静止（看似静止，实则是覆盖了一个全屏透明窗口）。暗化（Dimming）：全屏覆盖一层黑色遮罩（Opacity 0.15），仅光标所在区域高亮。智能嗅探（Smart Detection）：利用 SCShareableContent 实时获取光标下的 SCWindow 信息。视觉反馈：在识别到的窗口周围绘制一道 2px 宽的**电光蓝（Electric Blue）或霓虹紫（Neon Purple）**边框。层级穿透：按住 Cmd 键可忽略顶层窗口，直接选取底层元素（如穿透 Finder 窗口选取背后的浏览器）。放大镜（Loupe）：在光标旁显示一个圆形放大镜，放大倍率 4x，显示像素网格，确保 1px 都不差。确认截取：点击：截取当前高亮的窗口。拖拽：手动绘制矩形区域。Esc：取消截图。
3.2 关键技术指标响应延迟：从按下快捷键到出现遮罩，延迟 < 50ms。窗口识别准确率：必须能识别 macOS 的圆角窗口（Window Corner Radius），截图结果必须带透明通道（Alpha Channel），保留窗口原本的阴影效果（Window Shadow）。
4. 功能模块三：悬浮缩略图与操作流 (Post-Capture Overlay)截图后的瞬间是用户决策的关键时刻。VibeSnap 拒绝直接把文件堆在桌面，而是提供一个优雅的悬浮窗。4.1 UI 设计位置：屏幕右下角（遵循 macOS 通知习惯）。样式：圆角矩形，Glassmorphism（毛玻璃）背景，微阴影。内容：截图的微缩略图。
4.2 交互逻辑自动消失：默认 5 秒无操作自动消失（静默保存）。拖拽（Drag & Drop）：用户可直接按住缩略图，将其拖入 Slack、iMessage 或 Finder。这是最高频的操作。快捷按钮（Hover 显示）：Copy：复制到剪贴板。Save：另存为。Pin：钉在屏幕上。Edit：进入标注模式。Close：废弃本次截图。
5. 功能模块四：极简标注编辑器 (The Minimalist Editor)拒绝复杂功能堆砌，VibeSnap 只提供最核心的 5 个工具。

5.1 工具集箭头（Arrow）：自动优化的贝塞尔曲线箭头，而非生硬的直线。矩形框（Rectangle）：用于框选重点。高亮笔（Highlighter）：模拟荧光笔效果，半透明叠加。马赛克/模糊（Blur）：开发者刚需。用于遮挡 API Key、用户头像等敏感信息。实现高斯模糊（Gaussian Blur）或像素化（Pixelate）滤镜。文本（Text）：支持系统默认字体的简洁文本输入。
5.2 交互细节无模态设计：编辑器本身也是一个悬浮窗，没有繁杂的菜单栏。撤销/重做：支持标准的 ⌘Z / ⇧⌘Z。

6. 功能模块五：钉图 (Pin-to-Screen)复刻 Shottr 的杀手级功能。
6.1 功能描述将截图以“置顶窗口”（Floating Window Level）的形式固定在屏幕上。透明度调节：鼠标悬停在钉图上时，滚动滚轮可调节图片透明度（10%-100%），方便开发者对着截图写代码（Onion Skinning 效果）。穿透模式：双击钉图可使其“鼠标穿透”，不再响应点击，仅作为视觉参考。
7. 功能模块六：支持快捷键管理

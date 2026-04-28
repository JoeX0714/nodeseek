# NodeSeek iOS Agent Instructions

## 1. 项目定位

这是一个 iOS Swift 项目，主工程为 `nodeseek.xcodeproj`，业务代码在 `nodeseek/`，单元测试在 `nodeseekTests/`，UI 测试在 `nodeseekUITests/`。

当前主要技术栈包括：

- UIKit
- AsyncDisplayKit / Texture
- DTCoreText
- Kingfisher
- Kanna
- WebKit
- JXPhotoBrowser

处理任务时应优先理解现有 VIPER/分层结构，不要为了局部改动引入新的架构风格。

## 2. 项目改动边界

- 证据优先：先看崩溃点、日志、调用栈、diff、相关代码，再决定修改。
- 最小修改：优先修根因，不顺手重构无关模块。
- 一次只处理一个主要问题，避免把 UI、网络、解析、缓存同时改动。
- 遇到复杂问题时先拆解计划，明确影响范围和验证方式。

## 3. 常用验证命令

不要频繁启动或重启模拟器；这会拖慢本机开发效率。能用编译、单元测试、窄范围测试验证时，不要默认跑完整模拟器流程。

优先使用本机已有 simulator：

```bash
xcodebuild test \
  -project nodeseek.xcodeproj \
  -scheme nodeseek \
  -destination 'platform=iOS Simulator,id=F1FA4EFA-0399-438E-AC84-9326D32938E4'
```

针对单个测试文件或测试类：

```bash
xcodebuild test \
  -project nodeseek.xcodeproj \
  -scheme nodeseek \
  -destination 'platform=iOS Simulator,id=F1FA4EFA-0399-438E-AC84-9326D32938E4' \
  -only-testing:nodeseekTests/PostDetailViewControllerTests
```

如果 simulator id 失效，先运行：

```bash
xcodebuild -showdestinations -project nodeseek.xcodeproj -scheme nodeseek
```

涉及 Swift 编译、测试、接口或 UI 节点生命周期时，应尽量跑对应的 `xcodebuild test`。

## 4. 详情页相关约定

详情页核心文件：

- `nodeseek/Features/PostDetail/PostDetailViewController.swift`
- `nodeseek/Features/PostDetail/Nodes/PostBodyCellNode.swift`
- `nodeseek/Features/PostDetail/Nodes/CommentCellNode.swift`

详情页包含富文本、图片附件、头像加载、评论列表和图片预览。修改时注意：

- DTCoreText 的布局和图片附件尺寸变更会影响 cell 高度。
- 图片加载完成后刷新布局要节流，避免频繁 `reloadData()` 造成抖动。
- 富文本 view 与 Texture node 生命周期要分清：node 可后台构造，UIKit view 只能在 Texture 加载 view 时创建和配置。
- 修详情页崩溃时，优先补覆盖 node 构造、布局、富文本配置的测试。

## 5. 网络与解析

核心网络与解析文件：

- `nodeseek/Core/NodeSeekService.swift`
- `nodeseek/Core/Networking/`
- `nodeseek/Core/Parsing/KannaNodeSeekParser.swift`
- `nodeseek/Core/Rendering/`

约定：

- 解析规则优先集中在 parser 或 `XPathRules`，不要把 HTML 细节散落到 ViewController。
- 网络请求头、Cookie、Cloudflare/challenge 相关逻辑优先复用已有 helper。
- 修改解析时优先增加 fixture 测试，不要只靠真实网络页面验证。

## 6. 测试习惯

- 新增 bugfix 时优先先写失败用例，再改生产代码。
- UI/节点生命周期问题可以用窄范围测试覆盖构造、布局、渲染入口。
- 解析问题优先使用 `nodeseekTests/Fixtures/` 中的 HTML fixture。
- 测试失败时先读完整错误，不要直接猜测修改。

# NodeSeek iOS V1 开发计划

> **给自动化执行者：** 实施本计划时必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`。每个步骤都使用复选框（`- [ ]`）跟踪进度。

**目标：** 做一个最小可用的 UIKit 版 NodeSeek iOS 客户端，支持浏览帖子列表、阅读帖子详情和评论、通过 WebView 登录、复用 Cookie 发起原生请求、回复帖子，并支持签到/任务页面；遇到登录、Cloudflare 挑战或无法解析的页面时回退到 WebView。

**架构：** App 使用单一 `UINavigationController` 作为主导航栈。功能页面按 VIPER 分层，网络请求、HTML 解析、Cookie 同步、挑战检测和 HTML 内容渲染放在 `nodeseek/Core`。先用 fixture 测试把解析器和渲染器打稳，再接 UI，避免页面开发时被 HTML 结构变化牵着走。

**技术栈：** Swift 5、UIKit、Swift Package Manager、Texture/AsyncDisplayKit、Kanna XPath、URLSession、WKWebView、Swift Testing、XCTest。

---

## 已阅读资料

- PRD：`docs/superpowers/specs/2026-04-27-nodeseek-ios-prd-design.md`
- 当前 App 文件：`nodeseek/AppDelegate.swift`、`nodeseek/SceneDelegate.swift`、`nodeseek/ViewController.swift`、`nodeseek/Info.plist`
- 当前测试文件：`nodeseekTests/nodeseekTests.swift`、`nodeseekUITests/nodeseekUITests.swift`
- 依赖判断：V1 使用 Swift Package Manager，不使用 CocoaPods。Texture 官方安装文档只列出 CocoaPods/Carthage，因此 SPM 路线需要先验证可用的 SPM fork（候选：`https://github.com/FluidGroup/Texture`）是否满足 license、API 和构建要求；Kanna 支持 XPath，且可通过 Swift Package Manager 接入（`https://github.com/tid-kijyun/Kanna`）。

## 目标文件结构

App 侧新增目录：

```text
nodeseek/
  App/
    AppRouter.swift
  Core/
    Domain/
      NodeSeekModels.swift
      NodeSeekResult.swift
    Networking/
      HTMLClient.swift
      HTTPHTMLClient.swift
      CookieBridge.swift
      ChallengeDetector.swift
      WebChallengeResolver.swift
    Parsing/
      NodeSeekParser.swift
      KannaNodeSeekParser.swift
      XPathRules.swift
    Rendering/
      HTMLContentRenderer.swift
      RenderedContentBlock.swift
  Features/
    PostList/
      PostListContract.swift
      PostListEntity.swift
      PostListViewController.swift
      PostListPresenter.swift
      PostListInteractor.swift
      PostListRouter.swift
      Nodes/PostSummaryCellNode.swift
    PostDetail/
      PostDetailContract.swift
      PostDetailEntity.swift
      PostDetailViewController.swift
      PostDetailPresenter.swift
      PostDetailInteractor.swift
      PostDetailRouter.swift
      Nodes/PostBodyCellNode.swift
      Nodes/CommentCellNode.swift
    ReplyComposer/
      ReplyComposerContract.swift
      ReplyComposerEntity.swift
      ReplyComposerViewController.swift
      ReplyComposerPresenter.swift
      ReplyComposerInteractor.swift
      ReplyComposerRouter.swift
    WebChallenge/
      WebChallengeContract.swift
      WebChallengeEntity.swift
      WebChallengeViewController.swift
      WebChallengePresenter.swift
      WebChallengeInteractor.swift
      WebChallengeRouter.swift
    CheckIn/
      CheckInContract.swift
      CheckInEntity.swift
      CheckInViewController.swift
      CheckInPresenter.swift
      CheckInInteractor.swift
      CheckInRouter.swift
    Account/
      AccountContract.swift
      AccountEntity.swift
      AccountViewController.swift
      AccountPresenter.swift
      AccountInteractor.swift
      AccountRouter.swift
```

测试侧新增目录：

```text
nodeseekTests/
  Fixtures/
    post-list-basic.html
    post-detail-basic.html
    reply-form-basic.html
    check-in-basic.html
    cloudflare-challenge.html
  Core/
    KannaNodeSeekParserTests.swift
    HTMLContentRendererTests.swift
    ChallengeDetectorTests.swift
    CookieBridgeTests.swift
  Features/
    PostListPresenterTests.swift
    PostDetailPresenterTests.swift
    ReplyComposerPresenterTests.swift
```

## 里程碑

1. 工程基础：依赖接入、App Shell、领域模型、HTML fixture。
2. 解析与渲染：XPath 解析器、手写 `NSMutableAttributedString` 渲染器。
3. 网络与挑战处理：URLSession HTML 请求、Cookie 同步、WKWebView fallback 契约。
4. 原生阅读链路：帖子列表、帖子详情、评论。
5. 登录后动作：登录、回复、签到、账号状态。
6. 开源准备：README、贡献说明、手动 QA 清单。

## 当前完成状态

- 已完成基础目录和骨架：`App`、`Core`、`Features`、`nodeseekTests` 下的主要目录已经创建。
- 已按本机 Xcode VIPER 模板重建功能模块骨架：每个模块统一包含 `Contract`、`ViewController`、`Presenter`、`Interactor`、`Entity`、`Router` 六件套。
- 已把 Router 入口统一为模板风格的 `static func createModule()`，ViewController 统一使用构造函数注入非可选 Presenter。
- 已完成最小领域模型、Core 协议、VIPER 模块壳、`AppRouter` 和 `PostList` 根页面。
- `PostListInteractor` 已加入写死假数据，首页进入后会展示 3 条种子帖子，不是空页面。
- `SceneDelegate` 已切到 `AppRouter().makeRootViewController()`。
- 已新增 `nodeseekTests/ArchitectureSkeletonTests.swift`，用于确认导航根和基础领域模型可编译。
- 已验证：`xcodebuild build-for-testing -project nodeseek.xcodeproj -scheme nodeseek -destination generic/platform=iOS -derivedDataPath /tmp/nodeseek-derived CODE_SIGNING_ALLOWED=NO` 成功。
- 已通过 Swift Package Manager 接入 Kanna 6.1.0，并生成 `Package.resolved`。
- 已通过 Swift Package Manager 接入 Texture/AsyncDisplayKit 3.0.4（`FluidGroup/Texture`），并验证可构建。

---

### Task 1：Swift Package 依赖接入（Kanna 与 Texture 已完成）

**文件：**
- 修改：`nodeseek.xcodeproj/project.pbxproj`，只允许由 Xcode Swift Package 集成自动生成依赖改动
- 可能新增或更新：`nodeseek.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [x] **Step 1：验证并添加 Texture Swift Package**

在 Xcode 中打开 `nodeseek.xcodeproj`：

- 进入 `File > Add Package Dependencies...`
- 优先验证 `https://github.com/FluidGroup/Texture` 是否能提供可用的 Texture/AsyncDisplayKit product。
- 记录所选 Texture SPM 包的仓库、版本、license 和 product 名称。
- 只把 Texture/AsyncDisplayKit 相关 product 加到 `nodeseek` target。
- 不把测试 target 直接链接到 Texture，除非后续测试需要。
- 当前结果：已接入 `https://github.com/FluidGroup/Texture.git`，版本 `3.0.4`，product 名称 `AsyncDisplayKit`，并加入 `nodeseek` target。

- [x] **Step 2：通过 Xcode 添加 Kanna Swift Package**

在同一个 Package Dependencies 面板添加：

- `https://github.com/tid-kijyun/Kanna`
- 将 `Kanna` product 加到 `nodeseek` target。
- 当前结果：已手动更新 `nodeseek.xcodeproj/project.pbxproj`，Kanna product 已加入 `nodeseek` target 的 Frameworks 和 package product dependencies。
- 当前解析版本：`Kanna 6.1.0`。

- [x] **Step 3：确认 Package.resolved**

检查是否生成或更新：

```text
nodeseek.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

当前结果：已生成 `nodeseek.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`，其中包含 Kanna 6.1.0 与 Texture 3.0.4。

- [x] **Step 4：验证 project 构建**

运行：

```bash
xcodebuild -project nodeseek.xcodeproj -scheme nodeseek -configuration Debug -destination generic/platform=iOS -derivedDataPath /tmp/nodeseek-derived CODE_SIGNING_ALLOWED=NO build
```

预期：输出 `BUILD SUCCEEDED`。

当前验证：`xcodebuild build-for-testing -project nodeseek.xcodeproj -scheme nodeseek -destination generic/platform=iOS -derivedDataPath /tmp/nodeseek-derived CODE_SIGNING_ALLOWED=NO -clonedSourcePackagesDirPath /tmp/nodeseek-spm` 输出 `TEST BUILD SUCCEEDED`。

- [ ] **Step 5：提交**

```bash
git add nodeseek.xcodeproj
git commit -m "chore: add Swift package dependencies"
```

### Task 2：领域模型与结果类型（骨架已完成）

**文件：**
- 新增：`nodeseek/Core/Domain/NodeSeekModels.swift`
- 新增：`nodeseek/Core/Domain/NodeSeekResult.swift`
- 修改：`nodeseekTests/nodeseekTests.swift`
- 当前补充：`nodeseekTests/ArchitectureSkeletonTests.swift` 已覆盖基础领域模型编译测试

- [ ] **Step 1：把模板单测替换成模型编译测试**

```swift
import Foundation
import Testing
@testable import nodeseek

struct NodeSeekModelTests {
    @Test func postSummaryKeepsCoreFields() {
        let post = PostSummary(
            id: "123",
            title: "测试帖子",
            url: URL(string: "https://www.nodeseek.com/post-123")!,
            authorName: "mist",
            nodeName: "VPS",
            replyCount: 2,
            lastActivityText: "1 分钟前"
        )

        #expect(post.id == "123")
        #expect(post.title == "测试帖子")
        #expect(post.replyCount == 2)
    }
}
```

- [ ] **Step 2：运行测试，确认 RED**

```bash
xcodebuild test -project nodeseek.xcodeproj -scheme nodeseek -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:nodeseekTests/NodeSeekModelTests
```

预期：失败，原因是 `PostSummary` 未定义。

- [ ] **Step 3：新增领域模型**

```swift
import Foundation

struct PostSummary: Equatable, Sendable {
    let id: String
    let title: String
    let url: URL
    let authorName: String
    let nodeName: String?
    let replyCount: Int
    let lastActivityText: String?
}

struct PostDetail: Equatable, Sendable {
    let id: String
    let title: String
    let authorName: String
    let metadataText: String?
    let contentHTML: String
    let comments: [Comment]
    let replyForm: ReplyForm?
}

struct Comment: Equatable, Sendable {
    let id: String
    let authorName: String
    let floorText: String?
    let createdAtText: String?
    let contentHTML: String
}

struct ReplyForm: Equatable, Sendable {
    let actionURL: URL
    let method: String
    let textFieldName: String
    let hiddenFields: [String: String]
}

struct CheckInState: Equatable, Sendable {
    let isCheckedIn: Bool
    let message: String
    let actionURL: URL?
    let hiddenFields: [String: String]
}

struct UserSummary: Equatable, Sendable {
    let displayName: String
    let isLoggedIn: Bool
}
```

- [ ] **Step 4：新增统一结果类型**

```swift
import Foundation

enum ChallengeKind: Equatable, Sendable {
    case loginRequired(URL)
    case cloudflare(URL)
    case blocked(URL)
    case unsupported(URL)
}

enum NodeSeekResult<Value: Sendable>: Sendable {
    case value(Value)
    case challenge(ChallengeKind)
}
```

- [ ] **Step 5：确认 GREEN**

再次运行 Step 2 的测试命令。预期：PASS。

- [ ] **Step 6：提交**

```bash
git add nodeseek/Core/Domain nodeseekTests/nodeseekTests.swift
git commit -m "feat: add NodeSeek domain models"
```

### Task 3：Fixture Loader 与解析器契约

**文件：**
- 新增：`nodeseek/Core/Parsing/NodeSeekParser.swift`
- 新增：`nodeseek/Core/Parsing/XPathRules.swift`
- 新增：`nodeseek/Core/Parsing/KannaNodeSeekParser.swift`
- 新增：`nodeseekTests/Fixtures/post-list-basic.html`
- 新增：`nodeseekTests/Fixtures/post-list-link-fallback.html`
- 新增：`nodeseekTests/Core/KannaNodeSeekParserTests.swift`
- 当前补充：`FixtureLoader` 先以内联测试 helper 形式放在 `KannaNodeSeekParserTests.swift`，等 fixture 增多后再拆独立文件。

- [x] **Step 1：新增帖子列表 fixture**

```html
<html>
  <body>
    <article class="post-item">
      <a class="post-title" href="/post-123">测试帖子</a>
      <a class="post-author" href="/user/mist">mist</a>
      <a class="post-node" href="/go/vps">VPS</a>
      <span class="reply-count">2</span>
      <span class="last-active">1 分钟前</span>
    </article>
  </body>
</html>
```

- [x] **Step 2：新增失败的解析测试**

```swift
import Foundation
import Testing
@testable import nodeseek

struct KannaNodeSeekParserTests {
    @Test func parsesPostListFixture() throws {
        let html = try FixtureLoader.html(named: "post-list-basic")
        let parser = KannaNodeSeekParser(baseURL: URL(string: "https://www.nodeseek.com")!)

        let posts = try parser.parsePostList(html: html)

        #expect(posts.count == 1)
        #expect(posts[0].id == "123")
        #expect(posts[0].title == "测试帖子")
        #expect(posts[0].authorName == "mist")
        #expect(posts[0].nodeName == "VPS")
        #expect(posts[0].replyCount == 2)
    }
}
```

- [x] **Step 3：运行测试，确认 RED**

```bash
xcodebuild test -project nodeseek.xcodeproj -scheme nodeseek -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:nodeseekTests/KannaNodeSeekParserTests
```

当前补充：基础 fixture 因已有初版 parser 直接通过；随后新增 `post-list-link-fallback.html` 覆盖 class 名变化场景，并确认该用例失败。

- [x] **Step 4：新增解析器协议和 XPath 规则**

```swift
import Foundation

protocol NodeSeekParser {
    func parsePostList(html: String) throws -> [PostSummary]
    func parsePostDetail(html: String, url: URL) throws -> PostDetail
    func parseReplyForm(html: String, pageURL: URL) throws -> ReplyForm
    func parseCheckInState(html: String, pageURL: URL) throws -> CheckInState
}

enum XPathRules {
    static let postListItems = "//article[contains(@class, 'post-item')]"
    static let postTitle = ".//*[contains(@class, 'post-title')]"
    static let postAuthor = ".//*[contains(@class, 'post-author')]"
    static let postNode = ".//*[contains(@class, 'post-node')]"
    static let replyCount = ".//*[contains(@class, 'reply-count')]"
    static let lastActive = ".//*[contains(@class, 'last-active')]"
}
```

- [x] **Step 5：新增 fixture loader**

```swift
import Foundation

private final class FixtureToken {}

enum FixtureLoader {
    static func html(named name: String) throws -> String {
        let bundle = Bundle(for: FixtureToken.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }
}
```

- [x] **Step 6：新增 Kanna 解析器实现**

实现 `KannaNodeSeekParser`：

- 使用 `Kanna.HTML(html:encoding:)` 解析 HTML。
- 所有 XPath 选择器从 `XPathRules` 读取。
- 相对 URL 统一基于 `https://www.nodeseek.com` 解析。
- `id` 从 `/post-123` 这类路径中取末尾数字。
- 当前补充：已增加 `/post-`、`/post/` 链接 fallback，class 名变化时仍可从帖子容器中提取作者、节点、回复数和时间。

- [x] **Step 7：确认 GREEN**

再次运行 Step 3 的测试命令。预期：PASS。当前已通过 `KannaNodeSeekParserTests` 两个用例。

- [ ] **Step 8：提交**

```bash
git add nodeseek/Core/Parsing nodeseekTests/Core nodeseekTests/Fixtures
git commit -m "feat: parse NodeSeek post list fixtures"
```

### Task 4：详情、评论、回复表单与签到解析

**文件：**
- 修改：`nodeseek/Core/Parsing/KannaNodeSeekParser.swift`
- 修改：`nodeseek/Core/Parsing/XPathRules.swift`
- 修改：`nodeseekTests/Core/KannaNodeSeekParserTests.swift`
- 新增：`nodeseekTests/Fixtures/post-detail-basic.html`
- 新增：`nodeseekTests/Fixtures/reply-form-basic.html`
- 新增：`nodeseekTests/Fixtures/check-in-basic.html`

- [ ] **Step 1：新增详情、回复表单、签到 fixture**

fixture 要覆盖：

- 帖子标题、作者、正文。
- 两条评论。
- 一个带 hidden token 的回复表单。
- 一个可提交的签到表单。

- [ ] **Step 2：新增失败测试**

测试至少覆盖：

```swift
#expect(detail.title == "测试帖子")
#expect(detail.comments.count == 2)
#expect(detail.replyForm?.textFieldName == "content")
#expect(form.hiddenFields["csrf"] == "fixture-token")
#expect(checkIn.isCheckedIn == false)
#expect(checkIn.actionURL?.absoluteString == "https://www.nodeseek.com/mission/daily")
```

- [ ] **Step 3：运行解析测试，确认 RED**

预期：详情、回复表单、签到解析相关断言失败。

- [ ] **Step 4：实现解析方法**

实现时拆出这些私有 helper：

- 文本清洗。
- URL 解析。
- hidden field 提取。
- 必需节点读取。

单个解析方法尽量控制在 80 行以内，避免 XPath 和业务字段混在一起。

- [ ] **Step 5：确认 GREEN**

```bash
xcodebuild test -project nodeseek.xcodeproj -scheme nodeseek -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:nodeseekTests/KannaNodeSeekParserTests
```

预期：PASS。

- [ ] **Step 6：提交**

```bash
git add nodeseek/Core/Parsing nodeseekTests/Core/KannaNodeSeekParserTests.swift nodeseekTests/Fixtures
git commit -m "feat: parse post detail and forms"
```

### Task 5：手写 HTML 内容渲染器

**文件：**
- 新增：`nodeseek/Core/Rendering/RenderedContentBlock.swift`
- 新增：`nodeseek/Core/Rendering/HTMLContentRenderer.swift`
- 新增：`nodeseekTests/Core/HTMLContentRendererTests.swift`

- [ ] **Step 1：新增失败的渲染测试**

覆盖这些标签和行为：

- `p`
- `br`
- `a`
- `span.emoji`
- `strong` / `b`
- `em` / `i`
- `code`
- `pre`
- `blockquote`
- `/jump?to=` 链接解码

- [ ] **Step 2：确认 RED**

预期：失败，原因是 `HTMLContentRenderer` 尚未定义。

- [ ] **Step 3：实现渲染模型**

```swift
import Foundation

enum RenderedContentBlock: Equatable {
    case text(NSAttributedString)
    case imagePlaceholder(URL?)
    case unsupported(reason: String)
}
```

- [ ] **Step 4：实现渲染器**

实现 `HTMLContentRenderer.render(fragment:baseURL:) -> [RenderedContentBlock]`：

- `p` 转成段落文本。
- `br` 转成换行。
- `a` 保留展示文本，并写入 `.link` attribute。
- 相对链接基于 `https://www.nodeseek.com` 解析。
- `/jump?to=` 只在目标是 `http` 或 `https` 时解码。
- `img` 先转成 `imagePlaceholder`。
- 不支持的复杂块返回 `unsupported`，由详情页决定是否回退 WebView。

- [ ] **Step 5：确认 GREEN**

运行 renderer 测试。预期：PASS。

- [ ] **Step 6：提交**

```bash
git add nodeseek/Core/Rendering nodeseekTests/Core/HTMLContentRendererTests.swift
git commit -m "feat: render supported HTML content"
```

### Task 6：HTMLClient 与挑战检测

**文件：**
- 新增：`nodeseek/Core/Networking/HTMLClient.swift`
- 新增：`nodeseek/Core/Networking/HTTPHTMLClient.swift`
- 新增：`nodeseek/Core/Networking/ChallengeDetector.swift`
- 新增：`nodeseekTests/Fixtures/cloudflare-challenge.html`
- 新增：`nodeseekTests/Core/ChallengeDetectorTests.swift`
- 当前补充：匿名抓取 `https://www.nodeseek.com/` 得到的是真实 Cloudflare `Just a moment...` 挑战页，不是帖子列表 DOM；因此已用该真实响应形态补充 challenge fixture，并让 `ChallengeDetector` 识别为 `.cloudflare`。真实帖子列表 fixture 仍需要通过已过挑战的浏览器会话或用户导出的 HTML 获取。

- [x] **Step 1：新增挑战检测测试**

覆盖：

- HTTP 403。
- HTTP 503。
- `/cdn-cgi/challenge-platform/`。
- `cf_clearance`。
- 登录表单标记。

- [x] **Step 2：确认 RED**

预期：失败，原因是 `ChallengeDetector` 尚未定义。

- [x] **Step 3：定义 HTML 响应与客户端协议**

```swift
import Foundation

struct HTMLResponse: Sendable {
    let statusCode: Int
    let headers: [AnyHashable: Any]
    let finalURL: URL
    let html: String
}

protocol HTMLClient: Sendable {
    func get(_ url: URL) async throws -> HTMLResponse
    func post(_ url: URL, formFields: [String: String]) async throws -> HTMLResponse
}
```

- [x] **Step 4：实现 ChallengeDetector**

`ChallengeDetector.detect(response:)` 返回 `ChallengeKind?`。只做检测和分类，不尝试自动通过挑战。当前已支持通过 403/503 状态码、Cloudflare server header、`Just a moment...`、`window._cf_chl_opt`、`/cdn-cgi/challenge-platform/` 等特征识别挑战页。

- [x] **Step 5：实现 HTTPHTMLClient**

使用：

- `URLSessionConfiguration.default`
- `HTTPCookieStorage.shared`
- 常见浏览器请求头
- 无后台批量抓取
- 无自动挑战绕过
- 当前补充：`HTTPHTMLClient` 已使用 `URLSession` 实现 GET/POST，并带移动 Safari 风格 UA、Accept、Accept-Language；不包含任何自动绕过 Cloudflare 的逻辑。

- [x] **Step 6：验证**

运行 challenge 测试和通用 iOS 构建。预期：测试通过，构建输出 `BUILD SUCCEEDED`。

- [ ] **Step 7：提交**

```bash
git add nodeseek/Core/Networking nodeseekTests/Core/ChallengeDetectorTests.swift nodeseekTests/Fixtures/cloudflare-challenge.html
git commit -m "feat: add HTML client and challenge detection"
```

### Task 7：CookieBridge 与 WebChallenge 契约

**文件：**
- 新增：`nodeseek/Core/Networking/CookieBridge.swift`
- 新增：`nodeseek/Core/Networking/WebChallengeResolver.swift`
- 新增：`nodeseek/Features/WebChallenge/WebChallengeViewController.swift`
- 新增：`nodeseek/Features/WebChallenge/WebChallengePresenter.swift`
- 新增：`nodeseek/Features/WebChallenge/WebChallengeRouter.swift`
- 新增：`nodeseekTests/Core/CookieBridgeTests.swift`
- 新增：`nodeseekTests/Features/WebChallengePresenterTests.swift`
- 当前补充：已实现 `WKHTTPCookieStore <-> HTTPCookieStorage.shared` 双向同步、清理；WebChallenge 在加载完成后判断页面是否仍为 Cloudflare challenge，非 challenge 时同步 cookie 并关闭，仍为 challenge 时留在 WebView 等用户继续手动验证。

- [x] **Step 1：新增 CookieBridge 测试**

用内存 cookie 验证：`nodeseek.com` 相关 cookie 可以同步到 `HTTPCookieStorage.shared`。

- [x] **Step 2：确认 RED**

预期：失败，原因是 `CookieBridge` 尚未定义。

- [x] **Step 3：实现 CookieBridge**

```swift
import WebKit

@MainActor
final class CookieBridge {
    func syncWebViewCookiesToURLSession() async
    func clearSession() async
}
```

- [x] **Step 4：实现 WebChallenge 模块壳**

使用 `WKWebView` 和 `WKWebsiteDataStore.default()`：

- 加载目标 URL。
- 提供关闭按钮。
- 关闭或完成后同步 Cookie。
- 通知调用方重试一次原生请求。

- [x] **Step 5：验证构建**

运行通用 iOS 构建。预期：`BUILD SUCCEEDED`。

- [ ] **Step 6：提交**

```bash
git add nodeseek/Core/Networking nodeseek/Features/WebChallenge nodeseekTests/Core/CookieBridgeTests.swift
git commit -m "feat: add web challenge cookie flow"
```

### Task 8：App Shell 与根导航（骨架已完成）

**文件：**
- 新增：`nodeseek/App/AppRouter.swift`
- 修改：`nodeseek/SceneDelegate.swift`
- 删除或替换：`nodeseek/ViewController.swift`
- 修改：`nodeseekUITests/nodeseekUITests.swift`
- 当前补充：已创建 `AppRouter`，并将根页面接到 `PostListRouter.createModule()`；`ViewController.swift` 暂时保留为未使用模板文件，后续清理任务中删除。

- [ ] **Step 1：新增启动 UI 测试断言**

更新 UI 测试，断言导航栏标题 `NodeSeek` 存在。

- [ ] **Step 2：确认 RED**

预期：失败，原因是根页面仍是临时 `ViewController`。

- [ ] **Step 3：实现 AppRouter**

`AppRouter.makeRootViewController()` 返回 `UINavigationController`，root 为 `PostListRouter.createModule()`。

- [ ] **Step 4：更新 SceneDelegate**

把 window 根控制器改成：

```swift
window.rootViewController = AppRouter().makeRootViewController()
```

- [ ] **Step 5：确认 GREEN**

运行可用模拟器上的 UI 启动测试，并运行通用 iOS 构建。

- [ ] **Step 6：提交**

```bash
git add nodeseek/App nodeseek/SceneDelegate.swift nodeseekUITests
git commit -m "feat: add app navigation shell"
```

### Task 9：PostList VIPER 模块（骨架已完成）

**文件：**
- 新增：`nodeseek/Features/PostList/PostListContract.swift`
- 新增：`nodeseek/Features/PostList/PostListEntity.swift`
- 新增：`nodeseek/Features/PostList/PostListViewController.swift`
- 新增：`nodeseek/Features/PostList/PostListPresenter.swift`
- 新增：`nodeseek/Features/PostList/PostListInteractor.swift`
- 新增：`nodeseek/Features/PostList/PostListRouter.swift`
- 新增：`nodeseek/Features/PostList/Nodes/PostSummaryCellNode.swift`
- 新增：`nodeseek/Core/NodeSeekService.swift`
- 新增：`nodeseekTests/Features/PostListPresenterTests.swift`
- 当前补充：已按本机 VIPER 模板创建 `PostList` 的 Contract、View、Presenter、Interactor、Entity、Router；`PostListInteractor` 内置 3 条假数据，后续步骤继续替换为 Texture 列表和真实服务。

- [ ] **Step 1：新增 Presenter 测试**

使用 fake interactor 覆盖：

- loading
- loaded
- empty
- error
- challenge

- [ ] **Step 2：确认 RED**

预期：失败，原因是 PostList 模块尚未定义。

- [x] **Step 3：实现 NodeSeekService 的帖子列表接口**

调用 `HTMLClient`、`ChallengeDetector`、`NodeSeekParser`，返回 `NodeSeekResult<[PostSummary]>`。
当前补充：已新增 `NodeSeekServiceTests`，覆盖 Cloudflare challenge 返回和正常 HTML 解析返回。

- [ ] **Step 4：实现 PostList VIPER**

使用 `ASTableNode` 或 `ASCollectionNode` 渲染：

- 标题
- 作者
- 节点名
- 回复数
- 最后活跃时间

- [ ] **Step 5：接入详情页导航**

用户点击帖子后，Router push 到 PostDetail。

- [ ] **Step 6：验证**

运行 Presenter 测试、通用 iOS 构建，并手动启动 App。

- [ ] **Step 7：提交**

```bash
git add nodeseek/Core nodeseek/Features/PostList nodeseekTests/Features/PostListPresenterTests.swift
git commit -m "feat: add native post list"
```

### Task 10：PostDetail 与评论（骨架已完成）

**文件：**
- 新增：`nodeseek/Features/PostDetail/PostDetailContract.swift`
- 新增：`nodeseek/Features/PostDetail/PostDetailEntity.swift`
- 新增：`nodeseek/Features/PostDetail/PostDetailViewController.swift`
- 新增：`nodeseek/Features/PostDetail/PostDetailPresenter.swift`
- 新增：`nodeseek/Features/PostDetail/PostDetailInteractor.swift`
- 新增：`nodeseek/Features/PostDetail/PostDetailRouter.swift`
- 新增：`nodeseek/Features/PostDetail/Nodes/PostBodyCellNode.swift`
- 新增：`nodeseek/Features/PostDetail/Nodes/CommentCellNode.swift`
- 新增：`nodeseekTests/Features/PostDetailPresenterTests.swift`
- 当前补充：已按本机 VIPER 模板创建 `PostDetail` 的 Contract、View、Presenter、Interactor、Entity、Router；点击首页种子帖子会进入详情骨架页，后续步骤继续接详情数据与 Texture 渲染。

- [ ] **Step 1：新增 Presenter 测试**

覆盖：

- 标题映射
- 作者映射
- 正文 block 渲染
- 评论映射
- 回复入口可用性
- challenge fallback

- [ ] **Step 2：确认 RED**

预期：失败，原因是 PostDetail 模块尚未定义。

- [ ] **Step 3：实现详情服务接口**

`fetchPostDetail(url:)` 返回 `NodeSeekResult<PostDetail>`。

- [ ] **Step 4：实现 PostDetail UI**

使用 `ASCollectionNode` 分区展示：

- header
- body blocks
- comments

遇到 `unsupported` block 时不要崩溃，展示 WebView fallback 入口。

- [ ] **Step 5：接入回复按钮**

- 有 `replyForm`：进入 ReplyComposer。
- 无 `replyForm`：打开 WebChallenge 显示帖子 URL。

- [ ] **Step 6：验证**

运行 Presenter 测试和通用 iOS 构建。

- [ ] **Step 7：提交**

```bash
git add nodeseek/Features/PostDetail nodeseek/Core nodeseekTests/Features/PostDetailPresenterTests.swift
git commit -m "feat: add native post detail"
```

### Task 11：ReplyComposer 回复模块（骨架已完成）

**文件：**
- 新增：`nodeseek/Features/ReplyComposer/ReplyComposerViewController.swift`
- 新增：`nodeseek/Features/ReplyComposer/ReplyComposerPresenter.swift`
- 新增：`nodeseek/Features/ReplyComposer/ReplyComposerInteractor.swift`
- 新增：`nodeseek/Features/ReplyComposer/ReplyComposerRouter.swift`
- 新增：`nodeseekTests/Features/ReplyComposerPresenterTests.swift`
- 当前补充：已创建 ReplyComposer 的 View、Presenter、Interactor 和 Router 占位文件。

- [ ] **Step 1：新增 Presenter 测试**

覆盖：

- 空回复校验
- 提交成功
- 提交失败
- challenge 响应

- [ ] **Step 2：确认 RED**

预期：失败，原因是 ReplyComposer 模块尚未定义。

- [ ] **Step 3：实现回复提交接口**

表单字段来自：

- `ReplyForm.hiddenFields`
- `ReplyForm.textFieldName`
- 用户输入内容

提交到 `ReplyForm.actionURL`。

- [ ] **Step 4：实现原生回复编辑器**

使用 `UITextView`，支持：

- 取消
- 发送
- loading 状态
- 简短错误提示

- [ ] **Step 5：提交成功后刷新详情页**

关闭 ReplyComposer，并让 PostDetail Presenter 重新加载详情。

- [ ] **Step 6：验证**

运行 Reply Presenter 测试和通用 iOS 构建。

- [ ] **Step 7：提交**

```bash
git add nodeseek/Features/ReplyComposer nodeseek/Core nodeseekTests/Features/ReplyComposerPresenterTests.swift
git commit -m "feat: add reply composer"
```

### Task 12：CheckIn 与 Account 流程（骨架已完成）

**文件：**
- 新增：`nodeseek/Features/CheckIn/CheckInViewController.swift`
- 新增：`nodeseek/Features/CheckIn/CheckInPresenter.swift`
- 新增：`nodeseek/Features/CheckIn/CheckInInteractor.swift`
- 新增：`nodeseek/Features/CheckIn/CheckInRouter.swift`
- 新增：`nodeseek/Features/Account/AccountViewController.swift`
- 新增：`nodeseek/Features/Account/AccountPresenter.swift`
- 新增：`nodeseek/Features/Account/AccountRouter.swift`
- 修改：`nodeseek/Features/PostList/PostListViewController.swift`
- 当前补充：已创建 CheckIn 与 Account 的 View、Presenter、Interactor/Router 占位文件。

- [ ] **Step 1：新增 Presenter 测试**

覆盖：

- 签到状态展示
- 签到提交成功
- 账号登录状态
- 登录路由
- 清除 session

- [ ] **Step 2：确认 RED**

预期：失败，原因是 CheckIn 和 Account 模块尚未定义。

- [ ] **Step 3：实现 CheckIn 服务接口**

使用 parser 和 challenge detector 实现：

- `fetchCheckInState`
- `submitCheckIn`

- [ ] **Step 4：实现 Account 模块**

展示：

- 最小登录状态
- 登录入口，走 WebChallenge
- 清除 session，走 CookieBridge
- 项目 about 信息

- [ ] **Step 5：在 PostList 加入口**

- 导航栏左侧：Account
- 导航栏右侧：CheckIn

- [ ] **Step 6：验证**

运行单测、UI 启动测试和通用 iOS 构建。

- [ ] **Step 7：提交**

```bash
git add nodeseek/Features/CheckIn nodeseek/Features/Account nodeseek/Features/PostList nodeseek/Core
git commit -m "feat: add check-in and account flows"
```

### Task 13：文档与手动 QA

**文件：**
- 新增或修改：`README.md`
- 新增：`docs/qa/v1-manual-checklist.md`

- [ ] **Step 1：补 README**

README 需要说明：

- 项目定位：NodeSeek 社区 iOS 客户端。
- 已获站长许可的说明。
- 非爬虫、非绕过保护的原则。
- 架构概览。
- 依赖安装方式。
- XPath 修改必须补 fixture 测试。
- 为什么需要 WebView fallback。

- [ ] **Step 2：新增手动 QA 清单**

```text
- 启动 App，看到 NodeSeek 帖子列表。
- 打开帖子，能阅读正文和评论。
- 打开登录 WebView，并手动完成登录。
- 从 WebView 返回后，原生列表/详情可以重试。
- 对测试安全的帖子或 fixture 页面提交回复。
- 打开签到流程，确认结果状态。
- 触发 unsupported HTML fixture，确认进入 WebView fallback。
- 关闭网络，确认页面展示重试状态。
```

- [ ] **Step 3：最终验证**

```bash
xcodebuild test -project nodeseek.xcodeproj -scheme nodeseek -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild -project nodeseek.xcodeproj -scheme nodeseek -configuration Release -destination generic/platform=iOS -derivedDataPath /tmp/nodeseek-derived CODE_SIGNING_ALLOWED=NO build
```

预期：测试通过，Release 构建成功。

- [ ] **Step 4：提交**

```bash
git add README.md docs/qa
git commit -m "docs: describe NodeSeek iOS v1"
```

## 执行注意事项

- 每次提交只解决一个主要问题。
- 修改 XPath 前先加或更新 fixture 测试。
- CI 测试不要依赖实时 NodeSeek 网络请求。
- 不自动化绕过 Cloudflare。
- 解析置信度低时使用 WebView fallback。
- V1 保持单导航栈，不引入 TabBar。
- 当前 working tree 里同时存在根目录 Xcode 工程和旧的 `nodeseek/nodeseek/...` 跟踪路径。开始正式功能实现前，先处理这次工程迁移状态，否则后续 diff 会很难审。

## 自检

- PRD 覆盖：列表、详情、评论、WebView 登录、Cookie、回复、签到、挑战 fallback、fixture 测试、渲染器测试、README、无 TabBar 都已映射到任务。
- 依赖风险：Texture 和 Kanna 计划通过 Swift Package Manager 接入，不再使用 CocoaPods。
- 测试风险：核心解析、渲染、Presenter 状态走自动化测试；WebView 和真实挑战流程保留为手动 QA。
- 范围风险：V1 规模偏大。更稳的首个可演示目标是 Task 1-9，即先交付有解析测试支撑的原生帖子列表。

# User Info WebView Post Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route only NodeSeek post links clicked inside `UserInfoWebViewController` to the native post detail screen, including optional page and anchor fragments.

**Architecture:** Add one pure `SharedCore` route parser and reuse it from existing detail link resolution and the user-info WebView. Extend native post-detail creation to carry an optional initial anchor and scroll after first content render.

**Tech Stack:** Swift, UIKit, WebKit, Swift Testing, Xcode app-hosted tests, SwiftPM for `SharedCore`.

---

### Task 1: Shared Post Route Parser

**Files:**
- Create: `nodeseek/SharedCore/Domain/NodeSeekPostRoute.swift`
- Test: `nodeseekTests/SharedCore/NodeSeekPostRouteTests.swift`

- [ ] **Step 1: Write failing parser tests**

Add `nodeseekTests/SharedCore/NodeSeekPostRouteTests.swift`:

```swift
import Foundation
import Testing

#if SWIFT_PACKAGE
@testable import NodeSeekCore
#else
@testable import nodeseek
#endif

struct NodeSeekPostRouteTests {
    @Test func parsesPostPathWithoutPageAsPageOne() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(string: "/post-704174", relativeTo: baseURL))

        let route = try #require(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL))

        #expect(route.postID == "704174")
        #expect(route.page == 1)
        #expect(route.anchorID == nil)
        #expect(route.url.absoluteString == "https://www.nodeseek.com/post-704174")
    }

    @Test func parsesPostPathWithPageAndAnchor() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(string: "/post-704174-2#8", relativeTo: baseURL))

        let route = try #require(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL))

        #expect(route.postID == "704174")
        #expect(route.page == 2)
        #expect(route.anchorID == "8")
        #expect(route.url.absoluteString == "https://www.nodeseek.com/post-704174-2#8")
    }

    @Test func ignoresExternalPostLikePath() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(string: "https://example.com/post-704174-1"))

        #expect(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL) == nil)
    }

    @Test func ignoresJumpRedirectorEvenWhenTargetIsPost() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(string: "/jump?to=https%3A%2F%2Fwww.nodeseek.com%2Fpost-704174-1", relativeTo: baseURL))

        #expect(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL) == nil)
    }
}
```

- [ ] **Step 2: Run parser tests to verify RED**

Run: `swift test --filter NodeSeekPostRouteTests`

Expected: FAIL because `NodeSeekPostRouteResolver` does not exist.

- [ ] **Step 3: Add parser implementation**

Create `nodeseek/SharedCore/Domain/NodeSeekPostRoute.swift`:

```swift
import Foundation

nonisolated struct NodeSeekPostRoute: Equatable, Sendable {
    let postID: String
    let page: Int
    let anchorID: String?
    let url: URL
}

nonisolated enum NodeSeekPostRouteResolver {
    private static let postPathRegex = try! NSRegularExpression(
        pattern: "^/post-([0-9]+)(?:-([0-9]+))?/?$",
        options: []
    )

    static func route(for url: URL, baseURL: URL) -> NodeSeekPostRoute? {
        guard let resolvedURL = URL(string: url.relativeString, relativeTo: baseURL)?.absoluteURL,
              NodeSeekSite.isNodeSeekHost(resolvedURL),
              resolvedURL.path != "/jump" else {
            return nil
        }

        let path = resolvedURL.path
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = postPathRegex.firstMatch(in: path, options: [], range: range),
              match.numberOfRanges >= 3,
              let postIDRange = Range(match.range(at: 1), in: path) else {
            return nil
        }

        let postID = String(path[postIDRange])
        let page: Int
        if match.range(at: 2).location != NSNotFound,
           let pageRange = Range(match.range(at: 2), in: path) {
            page = max(Int(path[pageRange]) ?? 1, 1)
        } else {
            page = 1
        }

        return NodeSeekPostRoute(
            postID: postID,
            page: page,
            anchorID: normalizedAnchorID(from: resolvedURL),
            url: resolvedURL
        )
    }

    private static func normalizedAnchorID(from url: URL) -> String? {
        guard let fragment = url.fragment?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              fragment.isEmpty == false else {
            return nil
        }
        return fragment.hasPrefix("#") ? String(fragment.dropFirst()) : fragment
    }
}
```

- [ ] **Step 4: Run parser tests to verify GREEN**

Run: `swift test --filter NodeSeekPostRouteTests`

Expected: PASS for `NodeSeekPostRouteTests`.

### Task 2: Reuse Parser in Post Detail Link Resolution

**Files:**
- Modify: `nodeseek/Features/PostDetail/PostDetailViewController.swift`
- Test: `nodeseekTests/Features/PostDetailViewControllerTests.swift`

- [ ] **Step 1: Add failing regression for page-less post detail links**

Add a test near the existing `PostDetailLinkResolver` tests:

```swift
@Test func resolvesNodeSeekPostLinksWithoutPageToNativeDetailPageOne() throws {
    let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
    let url = try #require(URL(string: "/post-704174", relativeTo: baseURL)?.absoluteURL)

    let destination = try #require(PostDetailLinkResolver.destination(for: url, baseURL: baseURL))

    guard case .nativePost(let postID, let page, let resolvedURL) = destination else {
        Issue.record("Expected native post destination")
        return
    }
    #expect(postID == "704174")
    #expect(page == 1)
    #expect(resolvedURL.absoluteString == "https://www.nodeseek.com/post-704174")
}
```

- [ ] **Step 2: Run detail resolver test to verify RED**

Run: `make xcode-test-class TEST=PostDetailViewControllerTests`

Expected: FAIL for the new page-less link test because the current resolver requires `/post-id-page`.

- [ ] **Step 3: Use `NodeSeekPostRouteResolver` inside `PostDetailLinkResolver`**

Replace the private post regex branch in `PostDetailLinkResolver.destination` with:

```swift
if let route = NodeSeekPostRouteResolver.route(for: resolvedURL, baseURL: baseURL) {
    if let anchorID = route.anchorID,
       route.postID == currentPostID,
       route.page == max(currentPage, 1) {
        return .currentPageAnchor(anchorID)
    }
    return .nativePost(postID: route.postID, page: route.page, url: route.url)
}
```

Remove the now-unused private `postPathRegex` property.

- [ ] **Step 4: Run detail resolver test to verify GREEN**

Run: `make xcode-test-class TEST=PostDetailViewControllerTests`

Expected: PASS for `PostDetailViewControllerTests`.

### Task 3: Carry Initial Anchor into Native Detail

**Files:**
- Modify: `nodeseek/Features/PostDetail/PostDetailRouter.swift`
- Modify: `nodeseek/Features/PostDetail/PostDetailViewController.swift`
- Modify: `nodeseek/Features/PostDetail/PostDetailViewController+ViewProtocol.swift`
- Modify: `nodeseek/Features/PostDetail/PostDetailViewController+Web.swift`
- Test: `nodeseekTests/Features/PostDetailViewControllerTests.swift`

- [ ] **Step 1: Add failing view test for initial anchor consumption**

Add a DEBUG-visible assertion path and a test that creates `PostDetailViewController(presenter:initialAnchorID:)`, renders a detail with comments, waits for render, and expects the pending anchor to be consumed:

```swift
@Test func consumesInitialAnchorAfterFirstDetailRender() async throws {
    let presenter = SpyPostDetailPresenter()
    let viewController = PostDetailViewController(presenter: presenter, initialAnchorID: "2")
    viewController.loadViewIfNeeded()

    viewController.render(detail: PostDetail(
        id: "703863",
        title: "详情标题",
        authorName: "ipv4",
        avatarURL: nil,
        metadataText: "刚刚",
        contentHTML: "<p>正文</p>",
        comments: [
            Comment(id: "1", authorName: "a", avatarURL: nil, floorText: "#1", createdAtText: "1min ago", contentHTML: "<p>一楼</p>"),
            Comment(id: "2", authorName: "b", avatarURL: nil, floorText: "#2", createdAtText: "2min ago", contentHTML: "<p>二楼</p>")
        ],
        page: 1,
        pagination: nil
    ))
    await waitForDetailContent(in: viewController)

    #expect(viewController.testPendingInitialAnchorID == nil)
}
```

- [ ] **Step 2: Run anchor test to verify RED**

Run: `make xcode-test-class TEST=PostDetailViewControllerTests`

Expected: FAIL because `initialAnchorID` support does not exist.

- [ ] **Step 3: Add minimal anchor plumbing**

Make these signature and property changes:

```swift
static func createModule(post: PostSummary? = nil, page: Int = 1, initialAnchorID: String? = nil) -> UIViewController
```

```swift
init(
    presenter: PostDetailPresenterProtocol,
    initialHeader: PostDetailHeaderContent? = nil,
    sourcePostURL: URL? = nil,
    currentPage: Int = 1,
    initialAnchorID: String? = nil
)
```

Add `var pendingInitialAnchorID: String?` to `PostDetailViewController`, initialize it from `initialAnchorID`, and add:

```swift
func consumeInitialAnchorIfNeeded() {
    guard let anchorID = pendingInitialAnchorID else { return }
    pendingInitialAnchorID = nil
    DispatchQueue.main.async { [weak self] in
        self?.scrollToCurrentPageAnchor(anchorID)
    }
}
```

Call `consumeInitialAnchorIfNeeded()` after first detail content render in `PostDetailViewController+ViewProtocol.swift`.

In DEBUG add:

```swift
var testPendingInitialAnchorID: String? {
    pendingInitialAnchorID
}
```

Pass anchors from content link taps:

```swift
let viewController = PostDetailRouter.createModule(post: post, page: page, initialAnchorID: url.fragment)
```

- [ ] **Step 4: Run anchor test to verify GREEN**

Run: `make xcode-test-class TEST=PostDetailViewControllerTests`

Expected: PASS for `PostDetailViewControllerTests`.

### Task 4: User Info WebView Native Post Routing

**Files:**
- Modify: `nodeseek/AppRuntime/Web/UserInfoWebViewController.swift`
- Test: `nodeseekTests/AppRuntime/UserInfoWebViewControllerTests.swift`

- [ ] **Step 1: Add failing unit tests for route classification**

Add DEBUG-visible static helper tests:

```swift
@Test func classifiesPostLinkAsNativeRoute() throws {
    let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
    let url = try #require(URL(string: "/post-704174-2#8", relativeTo: baseURL))

    let route = try #require(UserInfoWebViewController.nativePostRoute(for: url, baseURL: baseURL))

    #expect(route.postID == "704174")
    #expect(route.page == 2)
    #expect(route.anchorID == "8")
}

@Test func doesNotClassifyNonPostNodeSeekLinkAsNativeRoute() throws {
    let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
    let url = try #require(URL(string: "/space/2000", relativeTo: baseURL))

    #expect(UserInfoWebViewController.nativePostRoute(for: url, baseURL: baseURL) == nil)
}
```

- [ ] **Step 2: Run user-info tests to verify RED**

Run: `make xcode-test-class TEST=UserInfoWebViewControllerTests`

Expected: FAIL because `nativePostRoute(for:baseURL:)` does not exist.

- [ ] **Step 3: Add native post navigation handling**

Add a static route helper:

```swift
static func nativePostRoute(for url: URL, baseURL: URL) -> NodeSeekPostRoute? {
    NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL)
}
```

Add a private instance method:

```swift
private func handleNativePostNavigationIfNeeded(_ url: URL) -> Bool {
    guard let route = Self.nativePostRoute(for: url, baseURL: currentPageURL()) else {
        return false
    }
    let post = PostSummary(
        id: route.postID,
        title: "帖子 #\(route.postID)",
        url: route.url,
        authorName: "",
        nodeName: nil,
        replyCount: 0,
        lastActivityText: nil
    )
    let viewController = PostDetailRouter.createModule(post: post, page: route.page, initialAnchorID: route.anchorID)
    if let navigationController {
        navigationController.pushViewController(viewController, animated: true)
    } else {
        present(UINavigationController(rootViewController: viewController), animated: true)
    }
    return true
}
```

Call it before external-link handling in `decidePolicyFor` and `createWebViewWith`.

- [ ] **Step 4: Run user-info tests to verify GREEN**

Run: `make xcode-test-class TEST=UserInfoWebViewControllerTests`

Expected: PASS for `UserInfoWebViewControllerTests`.

### Task 5: Final Verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run SwiftPM tests for pure parser**

Run: `swift test --filter NodeSeekPostRouteTests`

Expected: PASS.

- [ ] **Step 2: Run affected Xcode test classes**

Run:

```bash
make xcode-test-class TEST=PostDetailViewControllerTests
make xcode-test-class TEST=UserInfoWebViewControllerTests
```

Expected: PASS for both classes.

- [ ] **Step 3: Inspect diff**

Run: `git diff -- nodeseek/SharedCore/Domain/NodeSeekPostRoute.swift nodeseek/Features/PostDetail/PostDetailViewController.swift nodeseek/Features/PostDetail/PostDetailRouter.swift nodeseek/Features/PostDetail/PostDetailViewController+ViewProtocol.swift nodeseek/Features/PostDetail/PostDetailViewController+Web.swift nodeseek/AppRuntime/Web/UserInfoWebViewController.swift nodeseekTests/SharedCore/NodeSeekPostRouteTests.swift nodeseekTests/Features/PostDetailViewControllerTests.swift nodeseekTests/AppRuntime/UserInfoWebViewControllerTests.swift`

Expected: Diff only covers shared route parsing, native post routing, initial anchor plumbing, and tests.

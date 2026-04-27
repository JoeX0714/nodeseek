# NodeSeek iOS PRD and Technical Design

Date: 2026-04-27
Status: Draft for review
Project type: Open-source iOS client
Site: https://www.nodeseek.com

## 1. Background

NodeSeek currently does not have an official iOS client. This project aims to provide a lightweight open-source iOS client for the NodeSeek community, with site owner approval.

The client should not behave like a crawler or attempt to bypass site protection. It should act as a user-facing app that renders common NodeSeek pages natively where practical, while falling back to a real web environment when login, Cloudflare challenge, or page incompatibility requires it.

## 2. Product Positioning

NodeSeek iOS is a minimal, native-first iOS client for daily NodeSeek browsing and lightweight interaction.

The V1 product should feel closer to a focused reading and reply client than a full community super-app. The main path is:

1. Open the app.
2. Browse post list.
3. Open a post.
4. Read post content and comments.
5. Log in when needed.
6. Reply or complete check-in.
7. Use WebView only when authentication, Cloudflare, or fallback rendering is required.

## 3. V1 Scope

### 3.1 In Scope

V1 includes:

- Home or node post list.
- Post detail page.
- Comment viewing.
- Account login through WKWebView.
- Cookie reuse between WKWebView and native URLSession requests.
- Reply to an existing post.
- Check-in or task page support.
- Cloudflare/login-expired/challenge fallback through WKWebView.
- Manual HTML subset rendering into NSMutableAttributedString.
- XPath-based parsing tests using saved HTML fixtures.

### 3.2 Out of Scope

V1 does not include:

- Creating new posts.
- Private messages.
- Notification center.
- Search.
- Favorites or bookmarks.
- Full user settings.
- Moderation or admin features.
- Bottom tab navigation.
- SwiftUI implementation.
- Attempting to bypass Cloudflare or anti-bot systems.
- Bulk crawling, scraping, or background harvesting.

## 4. Product Principles

- Minimal first: one main navigation stack, no bottom tab bar.
- Native where it matters: lists, post detail, comments, reply, and check-in should use native UI.
- WebView as safety valve: login, Cloudflare challenge, unknown page state, and unrecoverable rendering failures use WKWebView.
- Respect site protection: do not attempt to defeat Cloudflare; use real user browser challenge flow when required.
- Maintainable parsing: XPath rules must be isolated, testable, and backed by HTML fixtures.
- Open-source friendly: clear architecture, modular VIPER structure, and contributor-oriented docs.

## 5. Information Architecture

The app uses a single UINavigationController stack.

```text
Root
  PostListViewController
    -> PostDetailViewController
      -> ReplyComposerViewController

Global modal flows
  -> WebChallengeViewController
  -> AccountViewController or login modal
  -> CheckInViewController or lightweight check-in modal
```

No UITabBarController is used in V1.

### 5.1 Post List

Purpose:

- Show latest or selected NodeSeek post list.
- Provide a lightweight node/category filter if parsing support is available.
- Provide top-level entry points for login/account and check-in.

Suggested layout:

```text
Navigation bar
  title: NodeSeek
  left: account/login status
  right: check-in

Content
  optional horizontal node filter
  post list
```

### 5.2 Post Detail

Purpose:

- Show post title, author, metadata, content, and comments.
- Provide reply entry.
- Fall back to WebView if the content cannot be safely parsed or rendered.

Suggested layout:

```text
Navigation bar
  back
  reply

Content
  post header
  post body
  comments
```

### 5.3 Reply Composer

Purpose:

- Let a logged-in user reply to the current post.
- Submit via the same form/token behavior used by the web page.

The composer uses UIKit native text input. It does not need Texture.

### 5.4 Web Challenge

Purpose:

- Handle login.
- Handle Cloudflare challenge.
- Handle login expiration.
- Display raw web page when native parsing/rendering fails.

The Web Challenge module is not only a login screen. It is a general web authentication and fallback resolver.

## 6. Technical Stack

V1 uses:

- UIKit for application shell, navigation, modal flows, text input, and WKWebView containers.
- Texture/AsyncDisplayKit for high-performance content rendering.
- VIPER architecture for page/module boundaries.
- URLSession for native HTML requests.
- XPath for extracting data from NodeSeek HTML.
- WKWebView for login, Cloudflare challenge, and fallback rendering.
- Manual NSMutableAttributedString construction for supported HTML content.

SwiftUI is not used.

The user's local VIPER Xcode template should be used for project/module scaffolding where possible. The exact generated file names and directory structure should follow the local template output, but the architecture responsibilities in this document remain the intended design.

## 7. Architecture Overview

```text
UIKit App Shell
  -> Single UINavigationController
  -> Modal presentation
  -> WKWebView containers

Texture Rendering Layer
  -> ASTableNode or ASCollectionNode for post list
  -> ASCollectionNode for post detail and comments
  -> ASCellNode subclasses for post cards, body blocks, comments, and check-in items

VIPER Modules
  -> PostList
  -> PostDetail
  -> ReplyComposer
  -> WebChallenge
  -> CheckIn
  -> Account

Core Services
  -> HTMLClient
  -> CookieBridge
  -> WebChallengeResolver
  -> NodeSeekService
  -> NodeSeekParser
  -> HTMLContentRenderer
```

## 8. VIPER Module Design

Each major feature uses VIPER.

```text
Module
  View
  Presenter
  Interactor
  Entity
  Router
```

### 8.1 View

Responsibilities:

- Own UIKit or Texture nodes.
- Forward user actions to Presenter.
- Render view models from Presenter.
- Avoid direct network calls.
- Avoid direct XPath parsing.

### 8.2 Presenter

Responsibilities:

- Convert entity models to display models.
- Coordinate loading, empty, error, and challenge states.
- Decide when to ask Router to navigate.
- Keep View logic lightweight.

### 8.3 Interactor

Responsibilities:

- Call NodeSeekService and other core services.
- Handle business flow for loading, replying, and check-in.
- Return domain entities to Presenter.

### 8.4 Entity

Responsibilities:

- Define domain models such as PostSummary, PostDetail, Comment, UserSummary, CheckInTask, and ParsedContentBlock.

### 8.5 Router

Responsibilities:

- Create modules.
- Push post detail.
- Present reply composer.
- Present WebChallengeViewController.
- Dismiss modal flows.

## 9. Proposed V1 Modules

### 9.1 PostList

Primary screen and app root.

Responsibilities:

- Load post list HTML through Interactor.
- Render posts with Texture.
- Navigate to post detail.
- Provide account/login and check-in entry points.
- Detect challenge state and route to WebChallenge.

### 9.2 PostDetail

Post reading screen.

Responsibilities:

- Load post detail HTML.
- Render post body and comments.
- Navigate to reply composer.
- Trigger WebChallenge when needed.
- Support pull-to-refresh if simple to implement.

### 9.3 ReplyComposer

Reply submission screen.

Responsibilities:

- Show native text editor.
- Validate non-empty reply.
- Ask Interactor to submit reply.
- Use parsed form action, CSRF token, and hidden fields from post detail or a fresh page request.
- Dismiss and refresh detail on success.

### 9.4 WebChallenge

Generic WebView resolver.

Responsibilities:

- Present WKWebView for login, Cloudflare challenge, or fallback page.
- Load a target URL.
- Detect navigation changes where practical.
- Allow user to close manually.
- Sync cookies after completion or dismissal.
- Notify caller to retry native request.

### 9.5 CheckIn

Lightweight check-in/task module.

Responsibilities:

- Load check-in/task page.
- Parse current check-in state.
- Submit check-in action when available.
- Show result state.
- Use WebChallenge when native request fails.

### 9.6 Account

Minimal account surface.

Responsibilities:

- Show login state.
- Open WebChallenge for login.
- Clear cookies/session.
- Show project/about information.

This should stay minimal in V1.

## 10. Core Services

### 10.1 HTMLClient

Purpose:

- Centralized URLSession HTML requester.

Responsibilities:

- Apply common headers.
- Use shared Cookie storage.
- Keep User-Agent aligned with WKWebView where possible.
- Decode response HTML.
- Return status code, headers, final URL, and body.
- Avoid aggressive concurrency.
- Provide simple retry only after WebChallenge completes.

### 10.2 CookieBridge

Purpose:

- Keep WKWebView and URLSession cookies in sync.

Responsibilities:

- Read cookies from WKWebsiteDataStore.default().httpCookieStore.
- Write relevant cookies into HTTPCookieStorage used by URLSession.
- Optionally sync URLSession cookies back to WebView when needed.
- Expose explicit sync points after login/challenge completion.

### 10.3 WebChallengeResolver

Purpose:

- Provide one flow for login, Cloudflare challenge, and fallback page display.

Responsibilities:

- Identify when a native request result needs WebView handling.
- Present WebChallenge module through Router.
- Sync cookies after WebView interaction.
- Retry the original native request once.
- Fall back to WebView display if retry still fails.

### 10.4 NodeSeekParser

Purpose:

- Extract NodeSeek entities from HTML.

Responsibilities:

- Parse post list.
- Parse post detail.
- Parse comments.
- Parse reply form action and hidden fields.
- Parse check-in/task state.
- Return typed entities, not UI view models.
- Keep XPath selectors centralized and covered by fixture tests.

### 10.5 NodeSeekService

Purpose:

- Business-facing facade over HTMLClient, WebChallengeResolver, CookieBridge, and NodeSeekParser.

Responsibilities:

- fetchPostList
- fetchPostDetail
- submitReply
- fetchCheckInState
- submitCheckIn
- expose login/challenge requirements as structured results

### 10.6 HTMLContentRenderer

Purpose:

- Convert supported post/comment HTML fragments into renderable content.

Responsibilities:

- Accept HTML fragment or parsed DOM nodes.
- Support a controlled HTML subset.
- Manually construct NSMutableAttributedString.
- Preserve links as attributes.
- Normalize paragraph spacing and line breaks.
- Avoid using system HTML importer as the primary rendering path.

## 11. HTML Rendering Strategy

Post bodies and comments may include HTML like:

```html
<article class="post-content"><p>感谢NS大佬模板</p>
<p>纯落地机，国际互联优秀，落地机，非直连鸡</p>
<p>流量：400G (双向)/月<br>
价格：35/半年，50/年<br>
付款方式：口令红包<br>
交付方式：ss协议</p>
<p>PM私信或者<a href="/jump?to=https%3A%2F%2Ft.me%2FAlexsQQ_bot" target="_blank">点击飞机tg联系</a></p>
<p><span class="emoji">🚫</span> 禁灰黑和jian zheng<br>
<span class="emoji">🚫</span> 禁止分享<br>
<span class="emoji">🚫</span> 禁止BT下载<br>
<span class="emoji">🚫</span> 跳车不退</p>
</article>
```

V1 should support this through manual NSMutableAttributedString construction.

Supported initial HTML subset:

- p
- br
- a
- span
- strong / b
- em / i
- code
- pre
- blockquote
- img as placeholder or fallback trigger

Rendering rules:

- p becomes paragraph text with spacing.
- br becomes a single line break.
- a preserves display text and stores a resolved URL in link attributes.
- relative links are resolved against https://www.nodeseek.com.
- /jump?to= links should be decoded into the destination URL when safe.
- span.emoji is rendered as normal text.
- unsupported inline tags are flattened into text when safe.
- unsupported block tags either flatten or trigger WebView fallback depending on complexity.

The system NSAttributedString HTML importer should not be the core path. It may be used only as an experimental fallback or debugging aid. Manual construction is preferred because it is faster, more predictable, easier to style, and safer with Texture.

Texture rendering options:

```text
Simple V1 path
  PostBodyCellNode
    -> ASTextNode.attributedText

More extensible path
  PostDetail ASCollectionNode
    -> TextBlockCellNode
    -> ImagePlaceholderCellNode
    -> QuoteCellNode
    -> CodeBlockCellNode
    -> CommentCellNode
```

The extensible block model is preferred if implementation cost stays reasonable.

## 12. Cloudflare and Web Challenge Handling

Cloudflare or other challenge pages can occur when accessing any HTML page, not only during login.

Any native HTML request may return:

- Normal NodeSeek HTML.
- Login-required page.
- Cloudflare challenge page.
- 403/503 response.
- Unexpected HTML that parser cannot handle.

The app should use one generic flow:

```text
URLSession requests HTML
  -> if normal: parse with XPath
  -> if challenge/login/blocked: present WKWebView for same URL
  -> user completes login/challenge
  -> sync cookies
  -> retry native request once
  -> if still blocked or unsupported: show WebView fallback
```

Detection signals may include:

- HTTP 403 or 503.
- HTML containing Cloudflare challenge markers.
- /cdn-cgi/challenge-platform/.
- cf_clearance references.
- challenge form markers.
- login form when authenticated action is required.
- parser unable to find required page anchors.

The app must not attempt to bypass or automate challenge solving. It should let the user complete verification in WKWebView.

## 13. Reply Flow

Replying is included in V1.

Expected flow:

```text
User taps Reply
  -> ensure login state
  -> load or reuse post detail HTML
  -> parse reply form action and hidden fields
  -> show ReplyComposerViewController
  -> submit form through NodeSeekService
  -> handle success/error/challenge
  -> refresh post detail on success
```

Reply submission should avoid hardcoding form fields when possible. The parser should extract:

- form action URL
- method
- CSRF token or hidden inputs
- textarea/input field name
- any required hidden metadata

If the reply form cannot be parsed, the app should open the post page in WebChallengeViewController as fallback.

## 14. Error and Fallback States

The app should handle these states without crashing:

- Network unavailable.
- HTTP blocked or challenged.
- Login expired.
- XPath parser mismatch.
- Reply token missing.
- Check-in state unknown.
- HTML content contains unsupported structures.

Recommended user-facing behavior:

- Show retry option for network failures.
- Show WebView verification prompt for challenge pages.
- Show WebView fallback for unsupported pages.
- Keep error copy short and practical.

## 15. Testing Strategy

V1 should include fixture-based parser tests.

Test categories:

- Post list parser fixtures.
- Post detail parser fixtures.
- Comment parser fixtures.
- Reply form parser fixtures.
- Check-in/task parser fixtures.
- HTMLContentRenderer tests for p/br/a/span/emoji/code/blockquote.
- CloudflareDetector tests using synthetic challenge-like HTML.

Testing principles:

- XPath changes require fixture tests.
- Parser tests should not require live network.
- Live NodeSeek requests should not be required for CI.
- Network and WebView behavior can be manually tested during development.

## 16. Open Source Notes

The repository should clearly state:

- The project is an open-source community iOS client for NodeSeek.
- Site owner approval has been obtained.
- The app is intended for normal user interaction, not crawling or bypassing protections.
- The app does not include bulk scraping features.
- WebView fallback exists to respect normal browser-based authentication and challenge flows.
- Contributions should include parser fixtures when updating XPath rules.

## 17. Success Criteria

V1 is successful when:

- Users can browse post list natively.
- Users can open and read post detail natively.
- Users can read comments natively.
- Users can log in through WKWebView.
- Cookies sync well enough for native requests after login.
- Users can reply to a post.
- Users can complete check-in/task flow.
- Cloudflare/login challenge does not cause white screen or crash.
- Unsupported pages have a WebView fallback.
- Parser and renderer tests cover the main supported HTML structures.
- Project README explains scope, architecture, and contribution rules.

## 18. Design Decisions Confirmed

- Use UIKit, not SwiftUI.
- Use Texture/AsyncDisplayKit for content rendering.
- Use VIPER architecture.
- Use the local VIPER Xcode template for scaffolding where possible.
- Use a single navigation stack, not bottom tabs.
- Use WKWebView for login, Cloudflare challenge, and fallback.
- Use URLSession for native HTML fetching.
- Use XPath for page parsing.
- Use manual NSMutableAttributedString construction for supported HTML content.
- Keep V1 minimal and avoid full community-app scope.

## 19. Open Questions for Later

These are intentionally deferred and should not block V1 PRD approval:

- Exact VIPER template output and folder naming.
- Exact XPath library choice.
- Whether post detail uses ASTableNode or ASCollectionNode.
- Whether content blocks are implemented immediately or after a simple ASTextNode V1.
- Exact check-in page behavior after inspecting live HTML.
- App icon/name final branding.

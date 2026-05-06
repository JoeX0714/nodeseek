# 用户信息 WebView 帖子链接原生跳转设计

## 背景

用户信息页当前由 `UserInfoWebViewController` 承载。这个 WebView 已经会把外站链接交给 `SFSafariViewController`，但 NodeSeek 站内链接默认继续在 WebView 内打开。

用户在个人主页、发帖记录或评论记录中点击帖子链接时，期望进入 App 原生帖子详情页，而不是继续在用户信息 WebView 中浏览帖子 HTML。

## 目标

- 只处理帖子详情链接，命中后跳转原生帖子详情页。
- 支持标准帖子路径 `/post-帖子ID-页码`。
- 支持省略页码的帖子路径 `/post-帖子ID`，默认进入第 1 页。
- 支持绝对链接、站内相对链接和带 fragment 的锚点链接。
- 保留锚点信息，例如 `/post-704174-2#8` 进入第 2 页并在详情加载后定位到 `#8`。
- 保持用户信息 WebView 对非帖子链接的现有行为。

## 非目标

- 不改变 `/space`、分类、通知、签到、搜索等非帖子站内链接的 WebView 行为。
- 不把 `/jump?to=...` 转成原生帖子详情；`/jump` 继续作为外链 redirector 边界处理。
- 不新增用户资料的原生页面。
- 不为 WebView 内所有 NodeSeek 路由建立统一原生导航系统。

## URL 规则

帖子链接只匹配 NodeSeek host 下的帖子路径：

```text
/post-704174
/post-704174-1
/post-704174-2#8
https://www.nodeseek.com/post-704174-2#8
```

解析结果包含：

```swift
struct NodeSeekPostRoute: Equatable {
    let postID: String
    let page: Int
    let anchorID: String?
    let url: URL
}
```

规则细节：

- `postID` 必须是非空数字。
- 页码缺失时使用 `1`。
- 页码小于 `1` 时归一化为 `1`。
- fragment 去掉空白和前导 `#` 后作为 `anchorID`。
- 非 NodeSeek host 不产生帖子路由。
- `/jump` 不产生帖子路由，即使 `to` 参数指向 NodeSeek 帖子。

## 架构

帖子 URL 解析应从 `PostDetailLinkResolver` 当前私有逻辑中抽出一个小的共享入口，避免 `UserInfoWebViewController` 再维护一份正则。

建议新增或扩展一个轻量类型，例如：

```swift
enum NodeSeekPostRouteResolver {
    static func route(for url: URL, baseURL: URL) -> NodeSeekPostRoute?
}
```

`PostDetailLinkResolver` 和 `UserInfoWebViewController` 都通过这个入口识别帖子链接。这样帖子路径、省略页码、fragment 等规则只有一处来源。

## 用户信息 WebView 流程

`UserInfoWebViewController` 在两个 WebView delegate 入口中处理帖子链接：

1. `webView(_:decidePolicyFor:decisionHandler:)`
2. `webView(_:createWebViewWith:for:windowFeatures:)`

当链接是用户点击触发，并且 `NodeSeekPostRouteResolver` 命中帖子路由时：

1. 取消 WebView 当前导航。
2. 用 `postID` 和 `url` 构造轻量 `PostSummary`。
3. 调用帖子详情模块创建方法，传入 `page` 和 `anchorID`。
4. 优先通过当前 `navigationController` push；没有导航控制器时用 `UINavigationController` 包一层 present。

非帖子链接继续走现有逻辑：

- 外站链接打开 `SFSafariViewController`。
- NodeSeek 非帖子站内链接留在用户信息 WebView。

## 帖子详情锚点流程

原生帖子详情需要接收初始锚点：

```swift
PostDetailRouter.createModule(post: post, page: page, initialAnchorID: anchorID)
```

`PostDetailViewController` 保存 `initialAnchorID`。当目标页内容渲染完成后，如果锚点存在，调用现有 `scrollToCurrentPageAnchor(_:)`。

如果锚点不存在或当前页面没有对应楼层，不显示错误，详情页保持正常打开状态。

## 验证计划

- `NodeSeekPostRouteResolver` 测试：
  - `/post-704174` 解析为第 1 页。
  - `/post-704174-2#8` 解析出 `postID = 704174`、`page = 2`、`anchorID = 8`。
  - 外站 `/post-704174-1` 不解析。
  - `/jump?to=https%3A%2F%2Fwww.nodeseek.com%2Fpost-704174-1` 不解析为帖子路由。
- `PostDetailLinkResolver` 回归测试：
  - 现有帖子详情内容中的帖子链接仍解析为 `.nativePost`。
  - 现有 `/jump` 行为仍解析为 Safari。
- `UserInfoWebViewController` 测试：
  - 帖子链接命中原生跳转路径。
  - 非帖子 NodeSeek 链接不触发原生帖子跳转。
- `PostDetailViewController` 测试：
  - 带 `initialAnchorID` 的详情在内容渲染后尝试滚动到对应楼层。
  - 不存在的锚点不影响详情正常展示。

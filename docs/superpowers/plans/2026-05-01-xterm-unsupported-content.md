# Xterm Unsupported Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace embedded xterm magic tab bodies with an unsupported-content notice and render that notice with a Safari SF Symbol in the post detail UI.

**Architecture:** Magic tab expansion detects xterm DOM and emits an internal unsupported marker instead of terminal text. Content block parsing converts that marker into `RenderedContentBlock.unsupported(reason:)`. The detail node factory renders unsupported blocks with a small text-plus-`safari` icon node.

**Tech Stack:** Swift, Swift Testing, Kanna, DTCoreText, AsyncDisplayKit/Texture, UIKit SF Symbols.

---

## File Structure

- Modify `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer.swift`
  - Add shared internal constants for the unsupported notice and marker class.
- Modify `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+MagicTabs.swift`
  - Detect xterm-related magic tab body HTML.
  - Replace the whole body with the unsupported marker HTML.
  - Keep ANSI code block sanitization intact.
- Modify `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+ContentBlocks.swift`
  - Include the unsupported marker in structured parsing detection.
  - Convert marker HTML into `.unsupported(reason:)`.
- Modify `nodeseek/Features/PostDetail/Nodes/DetailTableNode.swift`
  - Add `DetailUnsupportedContentNode`.
  - Render `.unsupported` with notice text plus SF Symbol `safari`.
- Modify `nodeseekTests/AppRuntime/DTCoreTextHTMLContentRendererTests.swift`
  - Update the xterm magic tab test to expect unsupported blocks instead of terminal text.
  - Add a helper for extracting unsupported reasons.
- Modify `nodeseekTests/Features/PostDetailViewControllerTests.swift`
  - Add a focused factory test for the unsupported Safari icon node.

## Task 1: Renderer Tests For Xterm Replacement

**Files:**
- Modify: `nodeseekTests/AppRuntime/DTCoreTextHTMLContentRendererTests.swift`

- [ ] **Step 1: Update the xterm magic tab test expectations**

Replace the assertions in `rendersMagicTabImagesAfterXtermDOMBodies` after `let renderedText = combinedText(in: blocks)` with:

```swift
let unsupportedReasons = unsupportedReasons(in: blocks)

#expect(renderedText.contains("💻基本信息"))
#expect(renderedText.contains("硬件质量体检报告") == false)
#expect(renderedText.contains("https://github.com/xykt/HardwareQuality") == false)
#expect(renderedText.contains("🎬IP质量"))
#expect(renderedText.contains("IP质量体检报告") == false)
#expect(renderedText.contains("报告链接：https://Report.Check.Place/ip/demo.svg") == false)
#expect(renderedText.contains("🌐网络质量"))
#expect(renderedText.contains("📍回程路由"))
#expect(renderedText.contains("xterm-fg-1") == false)
#expect(renderedText.contains("hidden helper") == false)
#expect(unsupportedReasons == [
    DTCoreTextHTMLContentRenderer.unsupportedXtermContentNotice,
    DTCoreTextHTMLContentRenderer.unsupportedXtermContentNotice
])
#expect(imageURLs(in: blocks).map(\.absoluteString) == [
    "https://i.111666.best/image/network.webp",
    "https://i.111666.best/image/route.webp"
])
```

- [ ] **Step 2: Add an unsupported reason helper**

Add this helper near the existing `codeBlocks(in:)` helper:

```swift
private func unsupportedReasons(in blocks: [RenderedContentBlock]) -> [String] {
    blocks.compactMap { block in
        guard case .unsupported(let reason) = block else { return nil }
        return reason
    }
}
```

- [ ] **Step 3: Run the focused renderer test and verify it fails**

Run:

```bash
make xcode-test-class TEST=DTCoreTextHTMLContentRendererTests
```

Expected: fail because xterm terminal text is still rendered and no unsupported reason is emitted.

## Task 2: Parser Implementation

**Files:**
- Modify: `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer.swift`
- Modify: `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+MagicTabs.swift`
- Modify: `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+ContentBlocks.swift`

- [ ] **Step 1: Add shared unsupported constants**

Add these constants inside `struct DTCoreTextHTMLContentRenderer`, near the other static constants:

```swift
static let unsupportedXtermContentNotice = "不支持显示此内容，请前往网页查看。"
static let unsupportedContentClassName = "nodeseek-unsupported-content"
```

- [ ] **Step 2: Replace xterm magic tab body HTML with an unsupported marker**

In `simplifiedMagicTabBodyHTML(_:)`, replace the current xterm extraction path with an early return:

```swift
func simplifiedMagicTabBodyHTML(_ bodyHTML: String) -> String {
    if isXtermMagicTabBodyHTML(bodyHTML) {
        return unsupportedContentHTML(reason: Self.unsupportedXtermContentNotice)
    }

    let mayContainANSICode = bodyHTML.contains("language-ansi") || bodyHTML.contains("data-ansicode")
    guard mayContainANSICode else { return bodyHTML }
    guard let document = try? HTML(
        html: "<div id=\"__nodeseek_magic_tab_body__\">\(bodyHTML)</div>",
        encoding: .utf8
    ),
          let root = document.at_css("#__nodeseek_magic_tab_body__") else {
        return bodyHTML
    }

    var blocks: [String] = []

    blocks.append(contentsOf: root.css("pre > code").compactMap { code -> String? in
        let isANSICode = hasClass("language-ansi", in: code) || (code.toHTML?.contains("data-ansicode") == true)
        guard isANSICode else { return nil }
        guard let rawText = code.text, rawText.isEmpty == false else { return nil }
        let normalizedText = stripANSICodes(from: rawText)
        guard normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        return "<pre><code>\(escapedHTML(normalizedText))</code></pre>"
    })

    for image in root.css("img") {
        if let imageHTML = image.toHTML {
            blocks.append(imageHTML)
        }
    }

    return blocks.isEmpty ? bodyHTML : blocks.joined(separator: "\n")
}
```

Then add these helper methods in the same extension:

```swift
func isXtermMagicTabBodyHTML(_ bodyHTML: String) -> Bool {
    let normalizedHTML = bodyHTML.lowercased()
    if normalizedHTML.contains("xterm-rows") {
        return true
    }
    return normalizedHTML.contains("terminal-container") && normalizedHTML.contains("xterm")
}

func unsupportedContentHTML(reason: String) -> String {
    "<p class=\"\(Self.unsupportedContentClassName)\">\(escapedHTML(reason))</p>"
}
```

- [ ] **Step 3: Teach content block parsing about the unsupported marker**

In `renderContentBlocks(fragment:baseURL:maxImageWidth:)`, extend `needsStructuredParsing`:

```swift
let needsStructuredParsing = fragment.range(of: "<table", options: [.caseInsensitive]) != nil
    || fragment.range(of: "<pre", options: [.caseInsensitive]) != nil
    || fragment.range(of: "<img", options: [.caseInsensitive]) != nil
    || fragment.range(of: Self.unsupportedContentClassName, options: [.caseInsensitive]) != nil
```

In `appendInlineContentBlocks(fromHTML:into:baseURL:maxImageWidth:)`, handle unsupported marker containers before image-only containers:

```swift
if let unsupportedBlock = unsupportedBlock(fromHTML: candidateHTML) {
    blocks.append(unsupportedBlock)
} else if let imageBlocks = standaloneImageBlocks(fromHTML: candidateHTML, baseURL: baseURL) {
    blocks.append(contentsOf: imageBlocks.map(RenderedContentBlock.image))
} else {
    appendTextBlocks(
        fromHTML: candidateHTML,
        into: &blocks,
        baseURL: baseURL,
        maxImageWidth: maxImageWidth
    )
}
```

Add this helper in the content blocks extension:

```swift
func unsupportedBlock(fromHTML html: String) -> RenderedContentBlock? {
    guard html.range(of: Self.unsupportedContentClassName, options: [.caseInsensitive]) != nil else {
        return nil
    }
    guard let document = try? HTML(html: html, encoding: .utf8),
          let marker = document.at_css(".\(Self.unsupportedContentClassName)") else {
        return nil
    }
    let reason = marker.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    return .unsupported(reason: reason?.isEmpty == false ? reason! : Self.unsupportedXtermContentNotice)
}
```

- [ ] **Step 4: Run the renderer test and verify it passes**

Run:

```bash
make xcode-test-class TEST=DTCoreTextHTMLContentRendererTests
```

Expected: `DTCoreTextHTMLContentRendererTests` passes.

- [ ] **Step 5: Commit parser behavior**

Run:

```bash
git add nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer.swift \
  nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+MagicTabs.swift \
  nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+ContentBlocks.swift \
  nodeseekTests/AppRuntime/DTCoreTextHTMLContentRendererTests.swift
git commit -m "fix: replace xterm magic tab bodies with unsupported notice"
```

## Task 3: Unsupported UI Node With Safari Icon

**Files:**
- Modify: `nodeseek/Features/PostDetail/Nodes/DetailTableNode.swift`
- Modify: `nodeseekTests/Features/PostDetailViewControllerTests.swift`

- [ ] **Step 1: Add a focused UI factory test**

Add this test near the existing detail content block node tests:

```swift
@Test func unsupportedContentNodeUsesSafariIcon() throws {
    let nodes = DetailContentBlockNodeFactory.makeNodes(
        from: [.unsupported(reason: DTCoreTextHTMLContentRenderer.unsupportedXtermContentNotice)],
        onImageTapped: { _, _ in },
        onLinkTapped: { _ in },
        onTextLayoutInvalidated: {}
    )

    let node = try #require(nodes.first as? DetailUnsupportedContentNode)
    #expect(node.reason == DTCoreTextHTMLContentRenderer.unsupportedXtermContentNotice)
    #expect(node.iconSymbolName == "safari")
}
```

- [ ] **Step 2: Run the focused UI test and verify it fails**

Run:

```bash
make xcode-test-class TEST=PostDetailViewControllerTests
```

Expected: fail because `DetailUnsupportedContentNode` does not exist and `.unsupported` still renders as a plain text node.

- [ ] **Step 3: Implement the unsupported content node**

In `DetailContentBlockNodeFactory.makeNodes`, replace:

```swift
case .unsupported(let reason):
    return plainTextNode(reason)
```

with:

```swift
case .unsupported(let reason):
    return DetailUnsupportedContentNode(reason: reason)
```

Add this class in `DetailTableNode.swift`, near the other detail content block nodes:

```swift
final class DetailUnsupportedContentNode: ASDisplayNode {
    let reason: String
    let iconSymbolName = "safari"

    private let textNode = ASTextNode()
    private let iconNode = ASImageNode()

    init(reason: String) {
        self.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        super.init()
        automaticallyManagesSubnodes = true
        isAccessibilityElement = true
        accessibilityLabel = self.reason

        textNode.maximumNumberOfLines = 0
        textNode.attributedText = NSAttributedString(
            string: self.reason,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )

        let icon = UIImage(systemName: iconSymbolName)?
            .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
        iconNode.image = icon
        iconNode.style.preferredSize = CGSize(width: 17, height: 17)
        iconNode.isAccessibilityElement = false
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        textNode.style.flexShrink = 1

        let stack = ASStackLayoutSpec.horizontal()
        stack.alignItems = .center
        stack.spacing = 6
        stack.children = [textNode, iconNode]
        return stack
    }
}
```

- [ ] **Step 4: Run the focused UI test and verify it passes**

Run:

```bash
make xcode-test-class TEST=PostDetailViewControllerTests
```

Expected: `PostDetailViewControllerTests` passes.

- [ ] **Step 5: Commit UI behavior**

Run:

```bash
git add nodeseek/Features/PostDetail/Nodes/DetailTableNode.swift \
  nodeseekTests/Features/PostDetailViewControllerTests.swift
git commit -m "feat: render unsupported content with safari icon"
```

## Task 4: Final Verification

**Files:**
- No source edits expected.

- [ ] **Step 1: Run focused runtime renderer tests**

Run:

```bash
make xcode-test-class TEST=DTCoreTextHTMLContentRendererTests
```

Expected: pass.

- [ ] **Step 2: Run focused detail UI tests**

Run:

```bash
make xcode-test-class TEST=PostDetailViewControllerTests
```

Expected: pass.

- [ ] **Step 3: Check git state**

Run:

```bash
git status --short --branch
```

Expected: on `feature/xterm-unsupported-content` with a clean working tree.

- [ ] **Step 4: Commit verification-only adjustments when source files changed**

If final verification required a small code or test correction, commit it with:

```bash
git status --short
git add nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer.swift \
  nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+MagicTabs.swift \
  nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+ContentBlocks.swift \
  nodeseek/Features/PostDetail/Nodes/DetailTableNode.swift \
  nodeseekTests/AppRuntime/DTCoreTextHTMLContentRendererTests.swift \
  nodeseekTests/Features/PostDetailViewControllerTests.swift
git commit -m "test: cover xterm unsupported rendering"
```

If no files changed after verification, do not create an empty commit.

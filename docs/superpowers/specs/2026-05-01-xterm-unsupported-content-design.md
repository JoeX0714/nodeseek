# Xterm Unsupported Content Design

## Goal

When a NodeSeek magic tab body contains embedded xterm terminal output, the iOS detail renderer should not parse or display the terminal DOM. It should replace that whole `nsk-magic-tab-body` with a clear unsupported-content notice and a Safari icon in the rendered UI.

## User-Facing Behavior

- If a magic tab body contains xterm terminal content, show:
  `不支持显示此内容，请前往网页查看。`
- The UI appends the SF Symbol `safari` after the notice.
- The affected body is replaced as a whole. Any `.xterm-rows`, terminal styles, hidden textarea helpers, and terminal spans inside that body are ignored.
- Other magic tab bodies in the same post continue rendering normally. For example, image-only bodies after the xterm body still produce image blocks.
- ANSI code blocks that do not use xterm DOM remain supported by the existing sanitizer.

## Detection Scope

The renderer treats a magic tab body as xterm-related when its HTML includes xterm terminal DOM markers:

- `xterm-rows`
- or a terminal container whose body also includes xterm-related class names

This keeps the behavior targeted at embedded xterm DOM, rather than disabling all code blocks or all ANSI-like content.

## Architecture

The implementation keeps parsing and presentation responsibilities separate.

1. `DTCoreTextHTMLContentRenderer+MagicTabs.swift` detects xterm-related magic tab bodies during magic tab expansion.
2. Instead of extracting `.xterm-rows` text, the expansion emits a small internal unsupported marker for that body.
3. `DTCoreTextHTMLContentRenderer+ContentBlocks.swift` converts the internal marker into `RenderedContentBlock.unsupported(reason:)`.
4. `DetailContentBlockNodeFactory` renders `.unsupported` as a lightweight text-plus-icon node. The text uses the existing unsupported secondary-label styling, and the icon uses SF Symbol `safari`.

The unsupported notice text should remain centralized so parsing tests and UI rendering use the same value.

## Files

- Modify `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+MagicTabs.swift`
  - Add the xterm body replacement path.
  - Stop producing code blocks from `.xterm-rows`.
- Modify `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer+ContentBlocks.swift`
  - Detect the internal unsupported marker and emit `.unsupported(reason:)`.
- Modify `nodeseek/AppRuntime/Rendering/DTCoreTextHTMLContentRenderer.swift`
  - Add shared constants for the unsupported notice and internal marker naming if that is the cleanest local fit.
- Modify `nodeseek/Features/PostDetail/Nodes/DetailTableNode.swift`
  - Replace the current plain unsupported text node with a text-plus-`safari` icon node.
- Modify `nodeseekTests/AppRuntime/DTCoreTextHTMLContentRendererTests.swift`
  - Update xterm magic tab expectations.
  - Keep assertions that terminal style/helper text is absent and later images remain.
- Modify UI tests only if the existing test harness can reliably inspect the unsupported node structure without fragile UIKit internals.

## Testing

The renderer tests should prove:

- xterm DOM text is not included in rendered output.
- terminal CSS class noise and hidden helper text are not included.
- the unsupported notice appears for each xterm magic tab body.
- later non-xterm magic tab images still render as image blocks.
- ANSI code block behavior remains covered by the existing test.

The UI test coverage should prove, when practical, that `.unsupported` renders with the Safari icon node. If direct inspection is too brittle, keep the behavior covered at the factory level with a small focused test rather than adding broad snapshot-style assertions.

## Out Of Scope

- Adding tap behavior to open the original webpage.
- Replacing generic code blocks or plain ANSI code blocks.
- Changing post parsing, network loading, or detail navigation behavior.

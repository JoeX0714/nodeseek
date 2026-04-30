# NodeSeek SPM And Xcodebuild Test Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a SwiftPM fast test path for pure Core logic and standardize faster local `xcodebuild` commands for App-hosted tests.

**Architecture:** Keep `nodeseek.xcodeproj` as the source of truth for the iOS App. Add a root `Package.swift` that points to selected existing source files for fast macOS-hosted SwiftPM tests, without moving the App to SwiftPM. Add local command targets for stable Xcode caches and `test-without-building`.

**Tech Stack:** Swift 5.9+ / Swift Testing, Swift Package Manager, Xcode `xcodebuild`, Kanna, existing UIKit App target.

---

## Current State

- `main` has been merged into `refactor/swiftpm` by fast-forward.
- `nodeseekUITests` target is gone from `nodeseek.xcodeproj`; `xcodebuild -list` now shows only `nodeseek` and `nodeseekTests`.
- `nodeseekTests` is still App-hosted:
  - `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/nodeseek.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/nodeseek"`
  - This means pure parser tests still launch the App host on a simulator.
- Measured local baseline before this plan:
  - `xcodebuild test` for `KannaNodeSeekParserTests`: 50-100 seconds.
  - `xcodebuild test-without-building` with stable cache: about 35 seconds.
  - `build-for-testing` hot cache: about 3 seconds.

## File Structure

- Create `Package.swift`
  - Defines `NodeSeekCore` and `NodeSeekCoreTests`.
  - Uses existing source files by path instead of moving directories.
- Modify `nodeseek/Core/Domain/NodeSeekModels.swift`
  - Move `AccountResponse` into Core because parser and service depend on it.
- Modify `nodeseek/Features/Account/AccountEntity.swift`
  - Keep `AccountRequest`.
  - Remove duplicate `AccountResponse`.
- Modify selected files under `nodeseekTests/Core/`
  - Add conditional test imports for SwiftPM and Xcode.
  - Make fixture loading work under both `Bundle.module` and XCTest bundles.
- Create `Makefile`
  - Adds repeatable commands for SwiftPM and optimized Xcode test flows.

---

### Task 1: Validate Post-Merge Project Shape

**Files:**
- Read: `nodeseek.xcodeproj/project.pbxproj`
- Read: `nodeseekTests/`

- [ ] **Step 1: Confirm UI test target is removed**

Run:

```bash
xcodebuild -list -project nodeseek.xcodeproj
```

Expected output includes:

```text
Targets:
    nodeseek
    nodeseekTests
```

Expected output does not include:

```text
nodeseekUITests
```

- [ ] **Step 2: Confirm unit tests are still App-hosted**

Run:

```bash
rg -n "TEST_HOST|BUNDLE_LOADER|nodeseekUITests" nodeseek.xcodeproj/project.pbxproj
```

Expected:

```text
BUNDLE_LOADER = "$(TEST_HOST)";
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/nodeseek.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/nodeseek";
```

Expected no result for:

```text
nodeseekUITests
```

- [ ] **Step 3: Run one current Xcode parser test as the control**

Run:

```bash
/usr/bin/time -p xcodebuild -quiet test-without-building \
  -project nodeseek.xcodeproj \
  -scheme nodeseek \
  -destination 'platform=iOS Simulator,id=F1FA4EFA-0399-438E-AC84-9326D32938E4' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:nodeseekTests/KannaNodeSeekParserTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected:

```text
Testing started
real 0.00
```

The value after `real` will vary by machine and cache state. Record the measured `real` value in the PR notes or final summary. Do not block implementation if it is still above 30 seconds; that is the known App-hosted baseline.

---

### Task 2: Move AccountResponse Into Core Domain

**Files:**
- Modify: `nodeseek/Core/Domain/NodeSeekModels.swift`
- Modify: `nodeseek/Features/Account/AccountEntity.swift`
- Test: `nodeseekTests/Core/KannaNodeSeekParserTests.swift`

- [ ] **Step 1: Add AccountResponse to Core models**

Add this code to `nodeseek/Core/Domain/NodeSeekModels.swift` after the `import Foundation` line and before `PostSummary`:

```swift
struct AccountResponse: Equatable, Sendable {
    let displayName: String
    let isLoggedIn: Bool
    let avatarURL: URL?
    let profileURL: URL?
    let stats: [String]

    init(
        displayName: String,
        isLoggedIn: Bool,
        avatarURL: URL? = nil,
        profileURL: URL? = nil,
        stats: [String] = []
    ) {
        self.displayName = displayName
        self.isLoggedIn = isLoggedIn
        self.avatarURL = avatarURL
        self.profileURL = profileURL
        self.stats = stats
    }
}
```

- [ ] **Step 2: Remove AccountResponse from AccountEntity**

Change `nodeseek/Features/Account/AccountEntity.swift` to:

```swift
//
//  AccountEntity.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

struct AccountRequest {
    let refresh: Bool
}
```

- [ ] **Step 3: Verify Xcode still compiles the moved type**

Run:

```bash
xcodebuild -quiet build-for-testing \
  -project nodeseek.xcodeproj \
  -scheme nodeseek \
  -destination 'platform=iOS Simulator,id=F1FA4EFA-0399-438E-AC84-9326D32938E4' \
  -derivedDataPath .build/XcodeDerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
```

Expected: command exits with status 0.

- [ ] **Step 4: Commit**

```bash
git add nodeseek/Core/Domain/NodeSeekModels.swift nodeseek/Features/Account/AccountEntity.swift
git commit -m "refactor: move account response into core domain"
```

---

### Task 3: Add Root SwiftPM Package For Core Tests

**Files:**
- Create: `Package.swift`
- Test: `swift test`

- [ ] **Step 1: Create Package.swift**

Create `Package.swift` at the repository root:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NodeSeek",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "NodeSeekCore", targets: ["NodeSeekCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/tid-kijyun/Kanna.git", exact: "6.1.0")
    ],
    targets: [
        .target(
            name: "NodeSeekCore",
            dependencies: [
                "Kanna"
            ],
            path: ".",
            sources: [
                "nodeseek/Core/Domain",
                "nodeseek/Core/Parsing",
                "nodeseek/Core/Networking/HTMLClient.swift",
                "nodeseek/Core/Networking/HTTPHTMLClient.swift",
                "nodeseek/Core/Networking/FormURLEncoder.swift",
                "nodeseek/Core/Networking/ChallengeDetector.swift",
                "nodeseek/Core/Networking/NodeSeekCommentSubmitter.swift",
                "nodeseek/Core/Networking/WebRequestFingerprint.swift",
                "nodeseek/Core/NodeSeekService.swift",
                "nodeseek/Core/CommentComposerContentBuilder.swift",
                "nodeseek/Core/Rendering/DetailImageLayout.swift"
            ]
        ),
        .testTarget(
            name: "NodeSeekCoreTests",
            dependencies: [
                "NodeSeekCore"
            ],
            path: ".",
            sources: [
                "nodeseekTests/Core/KannaNodeSeekParserTests.swift",
                "nodeseekTests/Core/ChallengeDetectorTests.swift",
                "nodeseekTests/Core/DetailImageLayoutTests.swift",
                "nodeseekTests/Core/NodeSeekServiceTests.swift",
                "nodeseekTests/Core/NodeSeekCommentSubmitterTests.swift",
                "nodeseekTests/Core/CommentComposerContentBuilderTests.swift"
            ],
            resources: [
                .copy("nodeseekTests/Fixtures")
            ]
        )
    ]
)
```

- [ ] **Step 2: Run SwiftPM once to expose compile errors**

Run:

```bash
swift test
```

Expected at this point: compile errors from test imports and fixture bundle access. Do not broaden the package to include UIKit/WebKit files to fix those errors.

- [ ] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "build: add SwiftPM core test package"
```

---

### Task 4: Make Core Tests Compile Under Xcode And SwiftPM

**Files:**
- Modify: `nodeseekTests/Core/KannaNodeSeekParserTests.swift`
- Modify: `nodeseekTests/Core/ChallengeDetectorTests.swift`
- Modify: `nodeseekTests/Core/DetailImageLayoutTests.swift`
- Modify: `nodeseekTests/Core/NodeSeekServiceTests.swift`
- Modify: `nodeseekTests/Core/NodeSeekCommentSubmitterTests.swift`
- Modify: `nodeseekTests/Core/CommentComposerContentBuilderTests.swift`

- [ ] **Step 1: Replace test module imports**

In each listed test file, replace:

```swift
@testable import nodeseek
```

with:

```swift
#if SWIFT_PACKAGE
@testable import NodeSeekCore
#else
@testable import nodeseek
#endif
```

- [ ] **Step 2: Update FixtureLoader for SwiftPM resources**

In `nodeseekTests/Core/KannaNodeSeekParserTests.swift`, change `FixtureLoader.html(named:)` to:

```swift
enum FixtureLoader {
    static func html(named name: String) throws -> String {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: FixtureToken.self)
        #endif
        let url = try #require(bundle.url(forResource: name, withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }
}
```

- [ ] **Step 3: Run SwiftPM test**

Run:

```bash
swift test
```

Expected:

```text
Test run with ... passed
```

If SwiftPM reports a missing UIKit/WebKit symbol, remove that test file from `NodeSeekCoreTests` rather than adding UIKit/WebKit sources to `NodeSeekCore`.

- [ ] **Step 4: Run Xcode parser test to ensure conditional imports did not break App tests**

Run:

```bash
xcodebuild -quiet test-without-building \
  -project nodeseek.xcodeproj \
  -scheme nodeseek \
  -destination 'platform=iOS Simulator,id=F1FA4EFA-0399-438E-AC84-9326D32938E4' \
  -derivedDataPath .build/XcodeDerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:nodeseekTests/KannaNodeSeekParserTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: command exits with status 0.

- [ ] **Step 5: Commit**

```bash
git add nodeseekTests/Core
git commit -m "test: support core tests under SwiftPM"
```

---

### Task 5: Add Repeatable Local Test Commands

**Files:**
- Create: `Makefile`
- Read: `AGENT.md`

- [ ] **Step 1: Create Makefile**

Create `Makefile`:

```makefile
.ONESHELL:
SHELL := bash
.SHELLFLAGS := -e -u -c -o pipefail
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

PROJECT := nodeseek.xcodeproj
SCHEME := nodeseek
SIMULATOR_ID ?= F1FA4EFA-0399-438E-AC84-9326D32938E4
DESTINATION := platform=iOS Simulator,id=$(SIMULATOR_ID)
DERIVED_DATA := .build/XcodeDerivedData
SOURCE_PACKAGES := .build/SourcePackages
XCODE_COMMON := -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) -clonedSourcePackagesDirPath $(SOURCE_PACKAGES) -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGNING_ALLOWED=NO

.PHONY: help spm-test xcode-build-tests xcode-test-core xcode-test-class xcode-test-full

help:
	@echo "Targets:"
	@echo "  make spm-test"
	@echo "  make xcode-build-tests"
	@echo "  make xcode-test-core"
	@echo "  make xcode-test-class TEST=KannaNodeSeekParserTests"
	@echo "  make xcode-test-full"

spm-test:
	swift test

xcode-build-tests:
	xcodebuild -quiet build-for-testing $(XCODE_COMMON)

xcode-test-core: xcode-build-tests
	xcodebuild -quiet test-without-building $(XCODE_COMMON) \
		-only-testing:nodeseekTests/KannaNodeSeekParserTests \
		-only-testing:nodeseekTests/ChallengeDetectorTests \
		-only-testing:nodeseekTests/DetailImageLayoutTests \
		-only-testing:nodeseekTests/NodeSeekServiceTests \
		-only-testing:nodeseekTests/NodeSeekCommentSubmitterTests \
		-only-testing:nodeseekTests/CommentComposerContentBuilderTests

xcode-test-class: xcode-build-tests
	@if [ -z "$${TEST:-}" ]; then echo "usage: make xcode-test-class TEST=KannaNodeSeekParserTests"; exit 2; fi
	xcodebuild -quiet test-without-building $(XCODE_COMMON) -only-testing:nodeseekTests/$$TEST

xcode-test-full:
	xcodebuild -quiet test $(XCODE_COMMON)
```

- [ ] **Step 2: Run SwiftPM command target**

Run:

```bash
make spm-test
```

Expected: same result as `swift test`.

- [ ] **Step 3: Run Xcode build target**

Run:

```bash
make xcode-build-tests
```

Expected: first run may take a while; second run should be near a few seconds if no source changed.

- [ ] **Step 4: Run one Xcode test class through Makefile**

Run:

```bash
make xcode-test-class TEST=KannaNodeSeekParserTests
```

Expected: command exits with status 0. Record elapsed wall time if comparing before/after.

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "build: add fast local test commands"
```

---

### Task 6: Document Source Placement And Testing Rules

**Files:**
- Modify: `AGENT.md`

- [ ] **Step 1: Update project structure rules**

In `AGENT.md`, add this section after `## 1. 项目定位`:

````markdown
## 1.1 目录与模块边界

主 App 仍然由 `nodeseek.xcodeproj` 管理，SwiftPM 只作为纯逻辑快速测试入口，不替代 iOS App 工程。

文件放置规则：

- `nodeseek/Core/Domain/`：纯数据模型、结果类型、跨 feature 共享的业务实体。不得依赖 UIKit、WebKit、Texture、DTCoreText、Kingfisher。
- `nodeseek/Core/Parsing/`：HTML 解析协议与 Kanna 实现。解析规则优先放在 `XPathRules.swift` 或 parser 内，不要散落到 ViewController。
- `nodeseek/Core/Networking/`：网络协议、URLSession 客户端、表单编码、challenge 检测、提交逻辑。WebKit 宿主类仍可放这里，但不能加入 SwiftPM target。
- `nodeseek/Core/Rendering/`：渲染输入/输出模型和布局纯函数。依赖 UIKit/DTCoreText 的渲染实现仍留在 Xcode App 测试路径，不加入 SwiftPM 快速测试路径。
- `nodeseek/Core/Imaging/`：图片下载、SVG/GIF/Kingfisher/SwiftDraw 相关逻辑。默认不加入 SwiftPM target。
- `nodeseek/Core/UI/`：UIKit 共享控件。只走 Xcode 构建和测试。
- `nodeseek/Features/`：VIPER feature 层。Presenter/Interactor 可以用 Xcode 单测；ViewController、Router、Texture node 走 App-hosted tests。
- `nodeseekTests/Core/`：Core 单测。纯 Foundation/CoreGraphics/Kanna 的测试优先纳入 SwiftPM；UIKit/WebKit/DTCoreText/Texture 测试继续只走 Xcode。
- `nodeseekTests/Features/`：feature 层测试。默认走 Xcode，除非明确拆出纯逻辑模块。

新增 SwiftPM 覆盖文件时，先确认该文件能在 macOS 测试进程中运行：

```text
不能依赖 App 启动
不能依赖模拟器
不能依赖 UIKit 生命周期
不能依赖 WebKit 页面加载
不能依赖 Texture node/view 生命周期
```
````

- [ ] **Step 2: Update common verification commands**

In `AGENT.md`, replace the test command section with:

````markdown
## 3. 常用验证命令

不要频繁启动或重启模拟器；这会拖慢本机开发效率。能用 SwiftPM 或窄范围单元测试验证时，不要默认跑完整模拟器流程。

测试选择规则：

- 改 `Core/Domain`、`Core/Parsing`、`Core/Networking` 中可独立运行的纯逻辑：先跑 `make spm-test`。
- 改 presenter/interactor 或仍依赖 App target 的单测：跑 `make xcode-test-class TEST=测试类名`。
- 改 UIKit、WebKit、Texture、DTCoreText、图片预览、App 生命周期：跑对应 Xcode 窄范围测试。
- 提交前如果改动跨 Core 和 UI，至少跑一次 `make xcode-build-tests`，必要时再跑 `make xcode-test-full`。

纯 Core 逻辑优先使用 SwiftPM：

```bash
make spm-test
```

App-hosted 单测先复用构建产物：

```bash
make xcode-test-class TEST=KannaNodeSeekParserTests
```

需要刷新 Xcode 测试构建产物：

```bash
make xcode-build-tests
```

完整 App 单测：

```bash
make xcode-test-full
```

如果 simulator id 失效，先运行：

```bash
xcodebuild -showdestinations -project nodeseek.xcodeproj -scheme nodeseek
```

涉及 Swift 编译、测试、接口或 UI 节点生命周期时，应尽量跑对应的验证命令并记录结果。
````

- [ ] **Step 3: Add SwiftPM maintenance rules**

In `AGENT.md`, add this section after the verification commands:

````markdown
## 3.1 SwiftPM 快速测试维护规则

`Package.swift` 是测试加速入口，不是 App 工程迁移入口。维护时遵守以下规则：

- 新增到 `NodeSeekCore` target 的源码必须能脱离 App host 编译。
- 如果某个文件 import 了 UIKit、WebKit、Texture、DTCoreText、Kingfisher、SwiftDraw，默认不要加入 `NodeSeekCore`。
- 如果测试因为缺少 UIKit/WebKit 类型失败，优先把该测试留在 Xcode 路径，不要为了让 `swift test` 通过而扩大 SwiftPM target。
- fixture 放在 `nodeseekTests/Fixtures/`，测试读取要同时兼容 `Bundle.module` 和 Xcode test bundle。
- Core 测试文件如需同时支持 SwiftPM 和 Xcode，使用：

```swift
#if SWIFT_PACKAGE
@testable import NodeSeekCore
#else
@testable import nodeseek
#endif
```

- SwiftPM 快速测试不替代最终 App 验证。涉及 UI、WebView、Texture node、DTCoreText 布局、图片加载和 App 导航时，仍需跑 Xcode 测试。
````

- [ ] **Step 4: Commit**

```bash
git add AGENT.md
git commit -m "docs: document fast test workflow"
```

---

### Task 7: Final Verification

**Files:**
- Read: `Package.swift`
- Read: `Makefile`
- Read: `AGENT.md`

- [ ] **Step 1: Verify SwiftPM fast path**

Run:

```bash
/usr/bin/time -p make spm-test
```

Expected:

```text
Test run with ... passed
real 0.00
```

The value after `real` will vary by machine and cache state. Target: hot-cache runs should be materially faster than App-hosted `xcodebuild` parser tests.

- [ ] **Step 2: Verify Xcode app-hosted path**

Run:

```bash
/usr/bin/time -p make xcode-test-class TEST=KannaNodeSeekParserTests
```

Expected:

```text
Testing started
real 0.00
```

This is expected to remain slower than `make spm-test` because `nodeseekTests` still uses `TEST_HOST`.

- [ ] **Step 3: Verify full build is not broken**

Run:

```bash
make xcode-build-tests
```

Expected: command exits with status 0.

- [ ] **Step 4: Summarize timings**

In the final response, include the measured wall-clock values from Steps 1-3 for:

- SPM core tests.
- Xcode parser test through Makefile.
- Xcode build-for-testing hot cache.

Do not claim the full Xcode path is fixed; describe it as optimized but still App-hosted.

# NodeSeek iOS

NodeSeek 三方 iOS 客户端，使用 UIKit 构建，基于 XPath/HTML 解析实现。

## 构建与测试

打开主工程：

```bash
open nodeseek.xcodeproj
```

运行纯逻辑测试：

```bash
make spm-test
```

构建 Xcode 测试产物：

```bash
make xcode-build-tests
```

运行指定 XCTest 类：

```bash
make xcode-test-class TEST=NodeSeekServiceTests
```

完整 App 单测：

```bash
make xcode-test-full
```

如本机模拟器 ID 不一致，可覆盖 `SIMULATOR_ID`：

```bash
make xcode-test-class TEST=NodeSeekServiceTests SIMULATOR_ID=<simulator-udid>
```

# NodeImage 授权与上传手动验证清单

日期：2026-05-06

## 背景

NodeImage 授权每天有次数限制，目前已经达到当日上限，今天不要再反复触发真实授权。后续等额度恢复后再按下面步骤验证。

## 验证前准备

- 使用当前分支：`feature/nodeimage-login-toolbar`
- 先确认 App 已登录 NodeSeek。
- 如果只是验证“取消授权”或“未授权 UI”，可以不触发真实 NodeImage 授权。
- 如果要验证完整授权链路，每次点击设置页 `NodeImage 授权` 或评论上传触发授权都可能消耗 NodeImage 授权次数，操作前先确认额度可用。

## 设置页验证

1. 打开 App 设置页。
2. 未保存 NodeImage API Key 时，应看到单独的 `NodeImage` 分区，按钮文案为 `NodeImage 授权`。
3. 点击 `NodeImage 授权`：
   - 应打开 `授权 NodeImage` WebView。
   - 正常情况下应先加载 `https://www.nodeimage.com/`，再自动点击页面里的授权入口。
   - 如果自动授权失败，可点击左上角 `填 Key`，手动粘贴 NodeImage API Key。
4. 授权成功后：
   - WebView 应关闭。
   - 设置页 NodeImage 分区应刷新为 `取消 NodeImage 授权`。
5. 点击 `取消 NodeImage 授权`：
   - 应只清除本机保存的 NodeImage API Key。
   - 不应退出 NodeSeek。
   - 分区文案应回到 `NodeImage 授权`。

## 评论上传验证

1. 打开任意帖子详情。
2. 点击评论入口。
3. 评论输入框上方应出现工具条。
4. 工具条里应包含：
   - 图片上传按钮
   - 表情按钮
   - 发送按钮
5. 未登录 NodeSeek 时点击评论、引用、发送或上传图片：
   - 应先提示登录。
   - 登录完成后再继续原动作。
6. 已登录 NodeSeek 但未授权 NodeImage 时点击图片上传：
   - 应进入 NodeImage 授权流程。
   - 授权成功后再打开系统图片选择器。
7. 已授权 NodeImage 时点击图片上传：
   - 应直接打开图片选择器。
   - 选择图片后应上传到 NodeImage。
   - 上传成功后应把 Markdown 图片链接插入评论输入框。

## 退出登录验证

1. 在设置页先完成或手动保存 NodeImage API Key。
2. 点击 `退出登录`。
3. 预期：
   - NodeSeek 登录状态被清除。
   - NodeImage API Key 同时被清除。
   - 重新进入设置页时，NodeImage 分区显示 `NodeImage 授权`。

## 风险点

- 直接打开 `https://www.nodeseek.com/connect?target=NodeImage` 可能不会完成授权，因为 NodeImage 页面需要保留 opener / popup / postMessage 流程。
- 当前授权页依赖 NodeImage 前端元素：
  - `startAuthBtn`
  - `apiKeyInput`
- 如果 NodeImage 改了页面结构，自动点击或自动读取 Key 可能失效，但手动 `填 Key` 入口应该仍可兜底。

## 自动化验证

不消耗授权次数的验证可以跑：

```bash
make xcode-test-class TEST=SettingsViewControllerTests
make xcode-test-class TEST=PostDetailLoginViewControllerTests
make xcode-test-class TEST=PostDetailPresenterTests
```

注意：真实 NodeImage 授权与上传仍需要手动验证，自动化测试只覆盖 UI 状态、Key 保存/清除、登录门禁和上传响应解析等本地逻辑。

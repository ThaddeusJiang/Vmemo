# 2026-02-07 管理端导入上传加速

## 背景
- 管理端导入 ZIP 上传通过 LiveView 默认 chunk_size=64_000 bytes，传输缓慢。

## 决策
- 提升 LiveView 上传 chunk_size 至 512 KiB，加快单文件传输速度，同时保持单消息在 Phoenix 默认限制以内。

## 变更
- `lib/vmemo_web/live/admin_import_live.ex`: allow_upload 增加 `chunk_size: 512 * 1024`。

## TODO
- 观察实际上传耗时与网络日志消息数量，必要时进一步调优 chunk_size 或采用直传存储。

---

## Admin Import 出现 "unmatched topic" (phx_reply)

### 现象
- 客户端收到 `phx_reply` 的 `status: "error"`, `response.reason: "unmatched topic"`。
- 来自 Phoenix Socket：当客户端向某个 topic 发消息时，服务端在 `state.channels` 里已找不到该 topic，会回复此错误（见 `deps/phoenix/lib/phoenix/socket.ex` 中 `encode_ignore`）。

### 常见原因
1. **Channel 已关闭但客户端仍发消息**：LiveView 进程已退出或 channel 已被服务端关闭（断线、超时、进程崩溃等），客户端仍用旧 topic 发送（如下一个 chunk、表单提交、重连等）。
2. **开发环境 code reload**：保存代码后 LiveView 进程重启、topic 变更，旧 topic 的后续请求会得到 "unmatched topic"。
3. **LongPoll**：Phoenix CHANGELOG 提到 LongPoll 在部分环境（如 iOS）可能引发此问题，已有修复（见 phoenix #6538）。

### 已做缓解
- **ImportZipWriter**：`init` 中改用 `File.mkdir_p/1`（不再用 `File.mkdir_p!`），创建目录失败时返回 `{:error, reason}` 而不是抛异常，避免上传阶段写文件导致 LiveView 进程崩溃，从而减少 channel 被意外关闭的情况。

### 若仍出现
- 上传大文件时：刷新页面后重试；开发时若刚改过代码，先刷新再操作。
- 生产环境：确认 Phoenix 版本已包含 LongPoll 相关修复；必要时拉取最新 phoenix/phoenix_live_view 的 issue 讨论。

---

## 大文件上传时保持 channel 不超时

### 机制
- LiveView 上传使用 **chunk_timeout**：若在指定毫秒内未收到**下一个 chunk**，会关闭该次上传的 channel（默认 10s，见 `Phoenix.LiveView.UploadConfig`）。
- 大 chunk（如 8MB）+ 慢网络时，单个 chunk 上传可能超过 10s，导致上传 channel 被关 → 出现 "unmatched topic" 等。

### 配置
- `allow_upload` 中增加 **chunk_timeout**（单位毫秒），按「最慢网络下单个 chunk 预计耗时」设大一些即可，每收到一个 chunk 会重新计时。
- 当前 admin import：`chunk_timeout: 120_000`（2 分钟），即相邻两 chunk 间隔不超过 2 分钟即保持 channel 不关。

### 可选
- 若仍遇超时，可再提高 `chunk_timeout`（如 300_000）或略减 `chunk_size` 以更频繁收到 chunk、重置计时。
- Endpoint 的 `:live_view` 里 `:hibernate_after` 控制的是 LiveView 进程空闲休眠时间，与「上传 channel 是否关闭」无关；上传期间有 chunk 到达即非空闲。

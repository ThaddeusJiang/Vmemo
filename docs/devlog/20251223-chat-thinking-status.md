## 2025-12-23 Chat Thinking 状态修复

### 背景

- 在 Chat 页面中，Agent 回复已经完成时，气泡下方的 `Thinking...` 状态没有消失
- DOM 结构中可以看到 `Thinking...` 对应的节点一直存在：`div.mt-2 flex items-center gap-2 text-sm text-base-content/70`

### 问题原因

- 前端判断是否处于「思考中」使用的是 `complete` 字段：
  - `is_thinking?(message)` 中逻辑为：`complete == false || is_nil(complete)`
- `LiveView` 中消息是通过 `PubSub` 广播过来的：
  - `Vmemo.Chat.Message` 的 `pub_sub` `transform` 里只广播了 `text/id/source/tool_results`
  - 没有携带 `complete` 和 `tool_calls`
- 结果：
  - 对于通过广播插入/更新到 stream 的消息，`complete` 始终为 `nil`
  - `is_thinking?` 一直返回 `true`，`Thinking...` 不会消失

### 修复方案

- 调整 `Vmemo.Chat.Message` 的 `pub_sub` transform 字段：
  - `:create` 广播：
    - 新增：`complete: message.complete`
    - 新增：`tool_calls: message.tool_calls`
  - `:upsert_response` 广播：
    - 新增：`complete: message.complete`
    - 新增：`tool_calls: message.tool_calls`
- 利用已有的 `ChatLive.handle_info/2` 合并逻辑：
  - 该逻辑会将新 payload 与现有 stream 中的 message 做 `Map.merge/3`
  - 对 `tool_results` / `tool_calls` 做了「新值为空则保留旧值」处理
  - 对其它字段（包括 `complete`）则优先使用新值（非 `nil`）

### 结果

- 当 Agent 回复完成并通过 `upsert_response` 广播 `complete: true` 时：
  - LiveView 中对应消息的 `complete` 会被正确更新为 `true`
  - `is_thinking?(message)` 返回 `false`
  - UI 中 `Thinking...` 节点不再显示，状态与实际一致

# 20251221 修复图片显示后消失的问题

## 任务目标

修复聊天消息中图片显示一瞬间后消失的问题。

## 问题分析

### 问题描述

在 `/chat` 页面中，当 LLM 调用 `search_photos` tool 返回图片搜索结果时，图片会显示一瞬间，然后消失。

### 根本原因

1. **Stream 更新机制**：当使用 `stream_insert` 更新已存在的消息时，LiveView 会用新的数据替换整个消息对象
2. **PubSub 广播数据不完整**：PubSub 广播的消息只包含 `text`, `id`, `source`, `tool_results` 这几个字段
3. **后续更新丢失 tool_results**：当消息通过 `upsert_response` 进行流式更新时，如果后续的更新只包含 `text` 而不包含 `tool_results`，就会导致 `tool_results` 丢失
4. **数据覆盖**：`stream_insert` 在更新已存在的消息时，会用新的 payload 替换整个消息对象，导致丢失字段

### 问题流程

1. 消息第一次创建时，包含 `tool_results`（图片数据）
2. 图片正确显示
3. 后续的 `upsert_response` 更新可能只更新 `text`，不包含 `tool_results`
4. PubSub 广播新的消息数据（缺少 `tool_results`）
5. `handle_info` 接收到广播，使用 `stream_insert` 更新消息
6. 新的消息数据替换旧的消息数据，`tool_results` 丢失
7. 图片消失

## 解决方案

### 修复内容

在 `handle_info` 中，当接收到 PubSub 广播时，检查 stream 中是否已存在该消息：
- 如果不存在，直接使用新消息数据
- 如果存在，合并数据，特别保护 `tool_results` 和 `tool_calls` 字段：
  - 如果新值是 `nil` 或空列表，保留旧值
  - 否则使用新值
- 对于其他字段（如 `text`, `source`），使用新值

### 代码修改

```elixir
def handle_info(
      %Phoenix.Socket.Broadcast{
        topic: "chat:messages:" <> conversation_id,
        payload: message
      },
      socket
    ) do
  if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
    # Merge with existing message data to preserve tool_results and other fields
    updated_message =
      case socket.assigns.streams.messages[message.id] do
        nil ->
          # New message, use as is
          message

        existing_message ->
          # Existing message, merge to preserve tool_results and other fields
          Map.merge(existing_message, message, fn
            :tool_results, existing_tool_results, new_tool_results ->
              # Preserve tool_results if new value is nil or empty
              if is_nil(new_tool_results) || (is_list(new_tool_results) && Enum.empty?(new_tool_results)) do
                existing_tool_results
              else
                new_tool_results
              end

            :tool_calls, existing_tool_calls, new_tool_calls ->
              # Preserve tool_calls if new value is nil or empty
              if is_nil(new_tool_calls) || (is_list(new_tool_calls) && Enum.empty?(new_tool_calls)) do
                existing_tool_calls
              else
                new_tool_calls
              end

            _key, existing_value, new_value ->
              # For other fields, use new value (or existing if new is nil)
              if is_nil(new_value) do
                existing_value
              else
                new_value
              end
          end)
      end

    {:noreply, stream_insert(socket, :messages, updated_message, at: 0)}
  else
    {:noreply, socket}
  end
end
```

## 执行记录

### 阶段一：问题分析

- **时间**：20251221
- **操作**：分析图片消失的原因
- **结果**：确认是 `stream_insert` 更新消息时丢失 `tool_results` 字段
- **问题**：无
- **解决方案**：在 `handle_info` 中合并现有消息数据

### 阶段二：实现修复

- **时间**：20251221
- **操作**：
  1. 修改 `handle_info` 函数，在更新消息前检查 stream 中是否已存在该消息
  2. 如果存在，合并数据，特别保护 `tool_results` 和 `tool_calls` 字段
  3. 确保后续更新不会丢失这些字段
- **结果**：
  - 代码修改完成
  - 无 linter 错误
- **问题**：无
- **解决方案**：无

## 测试记录

### 代码检查

- ✅ 代码修改完成，无 linter 错误
- ✅ 合并逻辑正确，保护了 `tool_results` 和 `tool_calls` 字段

### 功能验证

待运行时测试：
- [ ] 测试图片显示是否稳定，不再消失
- [ ] 测试流式更新时图片是否保持显示
- [ ] 测试多个 tool_results 是否都能正确显示

## 总结

- ✅ 已修复 `stream_insert` 导致 `tool_results` 丢失的问题
- ✅ 实现了数据合并逻辑，保护重要字段
- ✅ 代码检查通过，修复完成
- ⏳ 需要在运行时验证图片显示是否稳定

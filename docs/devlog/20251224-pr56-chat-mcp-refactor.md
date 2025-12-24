# 2025-12-24 PR 56: Chat 和 MCP 功能实现总结

## 概述

PR 56 实现了基于 Ash AI 的聊天功能和 MCP 服务器支持，包括：

- Chat 页面实现（/chat）
- 对话和消息管理
- MCP 服务器集成（支持图片搜索工具）
- 对话归档和删除功能
- MCP 认证和路由优化

## 核心功能

### 1. Chat 功能

**主要文件**：

- `lib/vmemo_web/live/chat_live.ex` - Chat LiveView
- `lib/vmemo/chat/conversation.ex` - Conversation 资源
- `lib/vmemo/chat/message.ex` - Message 资源
- `lib/vmemo/chat/message/changes/respond.ex` - AI 响应处理

**功能特性**：

- 基于 Ash AI 的对话系统
- 支持图片搜索工具（photo_search）
- 实时消息更新（PubSub）
- 对话标题编辑
- 消息中图片点击跳转
- 发送消息后自动重置表单

### 2. MCP 服务器

**主要文件**：

- `lib/vmemo_web/router.ex` - MCP 路由配置
- `lib/vmemo_web/mcp_auth.ex` - MCP 认证 Plug
- `lib/vmemo/photos.ex` - Photo 资源（包含 MCP tool）

**功能特性**：

- 支持 StreamableHttp 传输方式
- API Token 认证（可选）
- 图片搜索工具暴露
- 拒绝 GET 请求（仅支持 POST）

### 3. 数据库变更

**Migrations**：

- `20251223100000_create_conversations_and_messages.exs` - 创建 conversations 和 messages 表（包含 archived_at 和 CASCADE DELETE）

**关键设计**：

- 使用 uuidv7 作为主键
- CASCADE DELETE 处理关联删除
- archived_at 支持逻辑删除

## 关键问题和修复

### 1. Chat Thinking 状态不消失

**问题**：Agent 回复完成后，`Thinking...` 状态不消失

**原因**：

- 前端判断是否处于「思考中」使用的是 `complete` 字段：`complete == false || is_nil(complete)`
- `LiveView` 中消息是通过 `PubSub` 广播过来的
- `Vmemo.Chat.Message` 的 `pub_sub` `transform` 里只广播了 `text/id/source/tool_results`
- 没有携带 `complete` 和 `tool_calls`
- 对于通过广播插入/更新到 stream 的消息，`complete` 始终为 `nil`
- `is_thinking?` 一直返回 `true`，`Thinking...` 不会消失

**修复**：

- 调整 `Vmemo.Chat.Message` 的 `pub_sub` transform 字段：
  - `:create` 广播：新增 `complete: message.complete` 和 `tool_calls: message.tool_calls`
  - `:upsert_response` 广播：新增 `complete: message.complete` 和 `tool_calls: message.tool_calls`
- 利用已有的 `ChatLive.handle_info/2` 合并逻辑：
  - 该逻辑会将新 payload 与现有 stream 中的 message 做 `Map.merge/3`
  - 对 `tool_results` / `tool_calls` 做了「新值为空则保留旧值」处理
  - 对其它字段（包括 `complete`）则优先使用新值（非 `nil`）

**结果**：

- 当 Agent 回复完成并通过 `upsert_response` 广播 `complete: true` 时：
  - LiveView 中对应消息的 `complete` 会被正确更新为 `true`
  - `is_thinking?(message)` 返回 `false`
  - UI 中 `Thinking...` 节点不再显示，状态与实际一致

### 2. MCP 死循环问题

**问题**：客户端不断发送 GET 请求，导致数据库查询死循环

**原因**：

1. **认证逻辑问题**：`McpAuth` Plug 对所有请求（包括 GET）都进行认证，导致每次 GET 请求都触发数据库查询
2. **传输方式不匹配**：
   - 客户端使用 StreamableHttp（只需要 POST 请求）
   - 服务端同时支持 SSE（需要 GET 请求）和 StreamableHttp
   - GET 请求用于 SSE endpoint 发现，但客户端不需要这个功能
3. **客户端重试**：客户端可能因为 GET 请求响应不正确而不断重试

**修复方案**：

**第一阶段**：跳过 GET 请求的认证

- 修改 `lib/vmemo_web/mcp_auth.ex`，跳过 GET 请求的认证逻辑
- GET 请求直接通过，不触发数据库查询
- POST 请求仍然进行认证（如果需要）
- **结果**：数据库查询死循环已解决，但 GET 请求仍在重复

**第二阶段**：禁用 GET 请求

- GET 请求返回 `405 Method Not Allowed` 错误
- 错误消息明确告知客户端应该使用 POST 请求
- 更新路由配置，移除 `event-stream` 接受类型

**修改文件**：

- `lib/vmemo_web/mcp_auth.ex`：添加 GET 请求拒绝逻辑
- `lib/vmemo_web/router.ex`：更新 MCP pipeline，只接受 `json` 格式

**结果**：

- ✅ GET 请求返回 405 错误，包含明确的错误消息
- ✅ 数据库查询不再重复执行
- ✅ 客户端收到错误后应该停止重试 GET 请求
- ✅ POST 请求正常工作，支持 StreamableHttp 传输方式

### 3. 对话删除外键约束错误

**问题**：删除 conversation 时，由于 messages 表的外键约束导致删除失败

**原因**：数据库外键约束设置为 `NO ACTION`，需要手动删除关联记录

**修复**：

1. 创建迁移文件，将外键约束改为 `ON DELETE CASCADE`
2. 在 `Message` 资源中添加 `references` 配置，使用 `on_delete: :delete`
3. 简化 `DeleteMessagesBeforeDestroy` change 模块，依赖数据库 CASCADE

**优化点**：

- **使用数据库 CASCADE**：
  - 性能更好：数据库层面的级联删除比应用层删除更高效
  - 更可靠：数据库自动处理自引用关系的删除顺序
  - 代码更简洁：不需要手动管理删除顺序
- **AshPostgres `references` 配置**：
  - 配置在代码中，版本可控
  - 未来运行 `mix ash_postgres.generate_migrations` 会自动生成正确的约束
  - 符合 Ash 最佳实践

### 4. 对话归档和删除功能

**功能概述**：

- 在导航栏添加设置图标和下拉菜单
- 归档功能：设置 `archived_at` 时间戳，已归档对话不显示在列表中
- 删除功能：物理删除对话及其所有关联消息
- 成功/失败 toast 提示

**技术实现**：

**数据库层**：

- 添加 `archived_at` 字段到 conversations 表
- 添加 CASCADE DELETE 约束到 messages 表

**模型层**：

- `Conversation` 资源：
  - 添加 `archived_at` 属性（类型：`utc_datetime`）
  - 添加 `archive` action，使用 change 函数设置 `archived_at` 为当前时间
  - 更新 `my_conversations` 查询，过滤已归档的对话（`is_nil(archived_at)`）
  - `destroy` action 使用 `DeleteMessagesBeforeDestroy` change（已简化为空实现，依赖数据库 CASCADE）
- `Message` 资源：
  - 在 `postgres` 配置中添加 `references`：
    ```elixir
    references do
      reference :conversation, on_delete: :delete
      reference :response_to, on_delete: :delete
    end
    ```

**UI 层**：

- 在导航栏行尾添加设置图标（`hero-ellipsis-vertical`）
- 使用 daisyUI dropdown 组件显示菜单
- 菜单包含：
  - "Archive"：使用 `hero-archive-box` 图标
  - "Delete"：使用 `hero-trash` 图标，文字颜色为 error
- 实现事件处理：
  - `archive_conversation`：归档对话，从 stream 删除，显示 toast
  - `delete_conversation`：删除对话，从 stream 删除，显示 toast
- 修复 `stream_delete` 使用完整 conversation 对象（而不是 ID）
- 添加 `stream_configure` 配置，设置自定义 `dom_id`

**关键问题**：

- **问题 1**：`stream_delete` 参数错误 - `expected stream :conversations to be a struct or map with :id key`
  - **解决**：修改代码使用完整的 `conversation` 对象，而不是 `conversation_id`
- **问题 2**：自引用关系的删除顺序
  - **解决**：数据库 CASCADE 会自动递归处理自引用关系，无需手动处理删除顺序

### 5. 重置消息表单功能

**功能概述**：实现发送消息后自动重置表单的功能，清除输入框中的内容。

**技术方案**：
使用 Phoenix LiveView 的 `push_event` 机制，在服务器端发送事件，在客户端 JavaScript 中处理表单重置。

**代码变更**：

**服务器端** (`lib/vmemo_web/live/chat_live.ex`)：
在 `handle_event("send_message", ...)` 的成功分支中添加 `push_event`：

```elixir
socket
|> assign_message_form()
|> stream_insert(:messages, message, at: 0)
|> push_event("reset_form", %{form_id: "message-form"})
|> then(&{:noreply, &1})
```

**客户端** (`assets/js/app.js`)：
添加全局事件监听器来处理 `phx:reset_form` 事件：

```javascript
window.addEventListener("phx:reset_form", (event) => {
  const { form_id } = event.detail
  const form = document.getElementById(form_id)
  if (form) {
    form.reset()
  }
})
```

**技术细节**：

- **事件机制**：Phoenix LiveView 的 `push_event` 会在 DOM 上触发 `phx:` 前缀的自定义事件
- **表单重置**：使用原生 DOM API `form.reset()` 来重置表单
- **事件命名**：遵循项目中的命名约定，使用 `phx:reset_form` 事件名

## 技术细节

### PubSub 广播

Message 资源使用 PubSub 广播消息更新：

- `:create` 事件：广播新消息
- `:upsert_response` 事件：广播 AI 响应更新
- 包含字段：`id`, `text`, `source`, `complete`, `tool_calls`, `tool_results`

**消息合并逻辑**：

- 当接收到 PubSub 广播时，检查 stream 中是否已存在该消息
- 如果不存在，直接使用新消息数据
- 如果存在，合并数据，特别保护 `tool_results` 和 `tool_calls` 字段：
  - 如果新值是 `nil` 或空列表，保留旧值
  - 否则使用新值
- 对于其他字段（如 `text`, `source`, `complete`），使用新值

### MCP 认证

- 支持可选的 API Token 认证
- Token 验证失败时仍允许连接（支持公开工具）
- 使用 `Ash.PlugHelpers.set_actor/2` 设置 actor
- 仅支持 StreamableHttp（POST 请求），拒绝 GET 请求

### 图片搜索工具

- 工具名称：`photo_search`
- 基于 `Photo.hybrid_search` action
- 返回图片数据（id, url, note）
- 支持在聊天消息中显示图片
- 图片点击可跳转到详情页

## 相关文件

### 核心代码文件

- `lib/vmemo_web/live/chat_live.ex`
- `lib/vmemo/chat/conversation.ex`
- `lib/vmemo/chat/message.ex`
- `lib/vmemo/chat/message/changes/respond.ex`
- `lib/vmemo/chat/conversation/changes/delete_messages_before_destroy.ex`
- `lib/vmemo/chat.ex`
- `lib/vmemo_web/mcp_auth.ex`
- `lib/vmemo_web/router.ex`
- `lib/vmemo/photos.ex`

### 数据库迁移

- `priv/ash_repo/migrations/20251223100000_create_conversations_and_messages.exs`

### 相关文档

- `docs/tasks/todo/20251221-image-search-mcp-server.md` - MCP 服务器实现计划
- `docs/tasks/todo/20251224-fix-mcp-infinite-loop.md` - MCP 死循环修复任务
- `docs/tasks/todo/20251224-mcp-streamablehttp-support.md` - MCP StreamableHttp 支持优化

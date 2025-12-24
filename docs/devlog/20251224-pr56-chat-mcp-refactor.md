# 2025-12-24 PR 56: Chat 和 MCP 功能重构总结

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
- `20251223100000_create_conversations_and_messages.exs` - 创建 conversations 和 messages 表
- `20251223114213_add_archived_at_to_conversations.exs` - 添加 archived_at 字段
- `20251223122250_add_cascade_delete_to_messages.exs` - 添加 CASCADE DELETE 约束
- `20251224121701_add_usage_count_to_api_tokens.exs` - 添加 usage_count 字段

**关键设计**：
- 使用 uuidv7 作为主键
- CASCADE DELETE 处理关联删除
- archived_at 支持逻辑删除

## 关键问题和修复

### 1. Chat Thinking 状态不消失

**问题**：Agent 回复完成后，`Thinking...` 状态不消失

**原因**：PubSub 广播未包含 `complete` 字段

**修复**：在 `Message` 资源的 `pub_sub` transform 中添加 `complete` 和 `tool_calls` 字段

### 2. MCP 死循环问题

**问题**：客户端不断发送 GET 请求，导致数据库查询死循环

**原因**：客户端使用 StreamableHttp，但服务端同时支持 SSE（需要 GET 请求）

**修复**：
- GET 请求返回 405 Method Not Allowed
- 明确告知客户端使用 POST 请求
- 移除 `event-stream` 接受类型

### 3. 对话删除外键约束错误

**问题**：删除 conversation 时，由于 messages 表的外键约束导致删除失败

**修复**：
- 创建迁移文件，将外键约束改为 `ON DELETE CASCADE`
- 在 `Message` 资源中添加 `references` 配置

## 技术细节

### PubSub 广播

Message 资源使用 PubSub 广播消息更新：
- `:create` 事件：广播新消息
- `:upsert_response` 事件：广播 AI 响应更新
- 包含字段：`id`, `text`, `source`, `complete`, `tool_calls`, `tool_results`

### MCP 认证

- 支持可选的 API Token 认证
- Token 验证失败时仍允许连接（支持公开工具）
- 使用 `Ash.PlugHelpers.set_actor/2` 设置 actor

### 图片搜索工具

- 工具名称：`photo_search`
- 基于 `Photo.hybrid_search` action
- 返回图片数据（id, url, note）
- 支持在聊天消息中显示图片

## 相关文档

- `docs/devlog/20251223-chat-thinking-status.md` - Thinking 状态修复
- `docs/devlog/20251223-conversation-archive-delete.md` - 归档和删除功能
- `docs/devlog/20251223-reset-message-form.md` - 表单重置功能
- `docs/devlog/20251224-fix-mcp-infinite-loop.md` - MCP 死循环修复
- `docs/tasks/todo/20251221-image-search-mcp-server.md` - MCP 服务器实现计划

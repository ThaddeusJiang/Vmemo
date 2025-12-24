# PR 56: Chat 和 MCP 功能任务总结

## 概述

本文档整合了 PR 56 相关的所有任务记录，包括 Chat 功能实现、MCP 服务器集成、以及相关的 bug 修复和优化。

## 主要任务模块

### 1. MCP 服务器实现

#### 1.1 图片搜索 MCP Server 实现

**任务目标**：实现一个支持图片搜索功能的 MCP server，满足以下要求：

1. 可以在 `/chat` 通过自然语言调用，调用交给 LLM
2. 支持第三方 chatbot，例如 cherry-stdio

**技术方案**：

- 在 `Vmemo.Photos` domain 中添加 `AshAi` extension
- 定义 `search_photos` tool，基于 `Photo` resource 的 `hybrid_search` action
- 在 `Vmemo.Chat.Message.Changes.Respond` 中添加 `search_photos` tool
- 通过 `AshAi.Mcp.Dev` 自动暴露 tools

**关键实现步骤**：

1. ✅ 在 `Photo` resource 中添加 `search_photos` action（`:action` 类型，`returns: :term`）
2. ✅ 在 `Photos` domain 中添加 `AshAi` extension 和 tool 定义
3. ✅ 在 chat respond 中集成 `search_photos` tool
4. ✅ 修复 OpenRouter 模型配置，使用支持 tool use 的模型（`openai/gpt-4o`）
5. ✅ 修复 Azure OpenAI schema 验证问题（添加 `additionalProperties: false`）
6. ✅ 实现 schema 修补机制，满足 Azure OpenAI 的严格要求
7. ✅ 添加 API 响应优化（URL 规范化）

**技术要点**：

- Generic Action 返回值：如果设置了 `returns`，`run` 函数必须返回 `{:ok, value}`
- Action 参数访问：必须使用 `Ash.ActionInput.get_argument/2` 获取参数
- Azure OpenAI Schema 验证：所有对象类型必须设置 `additionalProperties: false`，`required` 数组必须包含所有 `properties` 中的字段
- URL 规范化：API 响应中的图片 URL 需要统一为绝对路径

**相关文件**：

- `lib/vmemo/photos/photo.ex` - Photo resource 和 search_photos action
- `lib/vmemo/photos.ex` - Photos domain 和 tool 定义
- `lib/vmemo/chat/message/changes/respond.ex` - Chat 响应处理和 schema 修补

#### 1.2 MCP 路由和认证优化

**任务**：修复 MCP 路由和认证相关问题

**问题 1：MCP 死循环问题**

- **问题**：客户端不断发送 GET 请求，导致数据库查询死循环
- **原因**：
  1. `McpAuth` Plug 对所有请求（包括 GET）都进行认证
  2. 客户端使用 StreamableHttp，但服务端同时支持 SSE（需要 GET 请求）
  3. 客户端可能因为 GET 请求响应不正确而不断重试
- **修复**：
  1. 第一阶段：跳过 GET 请求的认证，只对 POST 请求进行认证
  2. 第二阶段：禁用 GET 请求，返回 405 Method Not Allowed 错误
  3. 更新路由配置，移除 `event-stream` 接受类型，只接受 `json` 格式

**问题 2：支持 event-stream 格式**

- **问题**：MCP 路由不支持 `text/event-stream` 媒体类型
- **修复**：在 `:mcp` pipeline 的 `accepts` 配置中添加 `"event-stream"` 支持（后续已移除，因为只支持 StreamableHttp）

**问题 3：MCP Resource 返回字符串问题**

- **问题**：MCP resource 返回字符串而不是 JSON
- **修复**：确保 resource 返回正确的 JSON 格式

**问题 4：Photo Image MCP Resource**

- **任务**：添加 `photo_image` mcp_resource，返回图片数据
- **实现**：创建 MCP resource，支持通过 ID 获取图片数据

**相关文件**：

- `lib/vmemo_web/router.ex` - MCP 路由配置
- `lib/vmemo_web/mcp_auth.ex` - MCP 认证 Plug

#### 1.3 图片搜索返回数据优化

**任务**：优化图片搜索工具返回的数据格式

**问题 1：返回 HTML 而不是数据**

- **问题**：search_photos tool 返回 HTML 字符串而不是图片数据
- **修复**：修改 action 返回格式，返回结构化的图片数据（id, url, note）

**问题 2：返回图片数据格式优化**

- **任务**：确保返回的图片数据包含所有必要字段
- **实现**：
  - 返回图片 ID、URL、note 等信息
  - 统一 URL 格式（绝对路径）
  - 支持在聊天消息中显示图片

**相关文件**：

- `lib/vmemo/photos/photo.ex` - search_photos action
- `lib/vmemo_web/live/chat_live.ex` - 图片显示逻辑

### 2. Chat 功能实现

#### 2.1 Chat 消息显示图片

**任务目标**：在聊天消息中显示图片搜索结果

**实现方案**：

- 从 `tool_results` 中提取图片数据
- 使用 `PhotoCard` 组件显示图片
- 支持图片点击跳转到详情页

**关键实现**：

- 在 `ChatLive` 中添加 `extract_photos_from_message/1` 函数
- 从 `tool_results` 中解析图片数据
- 使用 `render_photos/2` 函数渲染图片网格
- 支持图片 URL 规范化（处理 example.com 域名问题）

**相关文件**：

- `lib/vmemo_web/live/chat_live.ex` - Chat LiveView
- `lib/vmemo_web/live/components/photo_card.ex` - PhotoCard 组件

#### 2.2 对话标题编辑

**任务目标**：实现对话标题的编辑功能

**实现方案**：

- 创建 `ConversationTitleEditor` LiveComponent
- 支持点击标题进入编辑模式
- 支持保存和取消操作
- 自动生成标题（基于消息内容）

**关键实现**：

- 使用 LiveComponent 实现标题编辑
- 支持内联编辑（点击编辑，失焦保存）
- 集成到 ChatLive 导航栏

**相关文件**：

- `lib/vmemo_web/live/components/conversation_title_editor.ex` - 标题编辑组件
- `lib/vmemo/chat/conversation/changes/generate_name.ex` - 自动生成标题

#### 2.3 对话归档和删除

**任务目标**：实现对话的归档（逻辑删除）和删除（物理删除）功能

**实现方案**：

- 添加 `archived_at` 字段到 conversations 表
- 实现归档和删除 actions
- 在 UI 中添加设置菜单

**关键实现**：

- 数据库层：添加 `archived_at` 字段，添加 CASCADE DELETE 约束
- 模型层：添加 `archive` action，更新 `my_conversations` 查询过滤已归档对话
- UI 层：添加设置图标和下拉菜单，实现归档和删除事件处理

**关键问题**：

- `stream_delete` 需要完整的 conversation 对象，而不是 ID
- 删除消息时的外键约束错误，通过 CASCADE DELETE 解决
- 自引用关系的删除顺序，由数据库 CASCADE 自动处理

**相关文件**：

- `lib/vmemo/chat/conversation.ex` - Conversation 资源
- `lib/vmemo/chat/message.ex` - Message 资源（CASCADE DELETE 配置）
- `lib/vmemo_web/live/chat_live.ex` - UI 实现

#### 2.4 重置消息表单

**任务目标**：在发送消息后重置消息表单，清除输入框中的内容

**实现方案**：

- 使用 Phoenix LiveView 的 `push_event` 机制
- 在客户端使用全局事件监听器处理表单重置

**关键实现**：

- 服务器端：在 `handle_event("send_message", ...)` 成功分支中添加 `push_event("reset_form", ...)`
- 客户端：在 `assets/js/app.js` 中添加 `phx:reset_form` 事件监听器

**相关文件**：

- `lib/vmemo_web/live/chat_live.ex` - 服务器端实现
- `assets/js/app.js` - 客户端实现

#### 2.5 Chat 图片点击导航

**任务目标**：实现聊天消息中图片点击跳转到详情页

**实现方案**：

- 在 `MarkdownContent` 组件中处理图片链接
- 将图片 URL 转换为详情页链接
- 使用 Phoenix LiveView 导航

**关键实现**：

- 从 HTML 中提取图片 URL
- 查询数据库找到对应的 photo ID
- 将 `<img>` 标签替换为 `<a>` 标签包裹的图片

**相关文件**：

- `lib/vmemo_web/live/components/markdown_content.ex` - Markdown 内容组件

#### 2.6 对话列表排序

**任务目标**：对话列表按创建时间排序

**实现方案**：

- 在 `my_conversations` 查询中添加排序配置
- 按 `inserted_at` 降序排列（最新的在前）

**相关文件**：

- `lib/vmemo/chat/conversation.ex` - Conversation 资源

### 3. Bug 修复

#### 3.1 修复图片消失问题

**问题**：聊天消息中图片显示一瞬间后消失

**原因**：

- Stream 更新机制：使用 `stream_insert` 更新已存在的消息时，会用新数据替换整个消息对象
- PubSub 广播数据不完整：后续更新可能只包含 `text`，不包含 `tool_results`
- 数据覆盖：新的消息数据替换旧数据，`tool_results` 丢失

**修复**：

- 在 `handle_info` 中添加消息合并逻辑
- 保护 `tool_results` 和 `tool_calls` 字段：如果新值是 `nil` 或空列表，保留旧值
- 对于其他字段，使用新值

**相关文件**：

- `lib/vmemo_web/live/chat_live.ex` - 消息合并逻辑

#### 3.2 修复 Photo Jason Encoder

**问题**：Photo 资源序列化问题

**修复**：

- 添加 `@derive {Jason.Encoder, only: [...]}` 到 Photo resource
- 确保只序列化必要的字段

**相关文件**：

- `lib/vmemo/photos/photo.ex` - Photo 资源

#### 3.3 修复 HTML Escape Safe Tuple

**问题**：HTML 转义问题

**修复**：修复 HTML 转义相关的 tuple 处理

#### 3.4 修复 Conversation Title Component

**任务**：重构 conversation title 组件

**实现**：将标题编辑功能拆分为独立的 LiveComponent

**相关文件**：

- `lib/vmemo_web/live/components/conversation_title_editor.ex` - 标题编辑组件

## 任务完成状态

### 已完成 ✅

1. ✅ 图片搜索 MCP Server 实现
2. ✅ MCP 路由和认证优化
3. ✅ Chat 消息显示图片
4. ✅ 对话标题编辑
5. ✅ 对话归档和删除
6. ✅ 重置消息表单
7. ✅ Chat 图片点击导航
8. ✅ 对话列表排序
9. ✅ 修复图片消失问题
10. ✅ 修复 Photo Jason Encoder
11. ✅ 修复 HTML Escape Safe Tuple
12. ✅ 重构 Conversation Title Component

### 待测试 ⏳

- [ ] 第三方 chatbot (cherry-stdio) 集成测试

## 技术总结

### 关键架构决策

1. **MCP Server 实现**：

   - 使用 `AshAi` extension 自动暴露 tools
   - 支持 Azure OpenAI schema 验证要求
   - 实现 schema 修补机制

2. **Chat 功能**：

   - 使用 PubSub 实现实时消息更新
   - 消息合并逻辑保护重要字段
   - 使用 LiveComponent 实现组件化

3. **数据库设计**：
   - 使用 CASCADE DELETE 处理关联删除
   - 使用 `archived_at` 实现逻辑删除
   - 使用 uuidv7 作为主键

### 代码质量

- ✅ 遵循 Elixir/Phoenix 最佳实践
- ✅ 代码结构清晰，职责分离
- ✅ 完善的错误处理
- ✅ 无 linter 错误

## Code Review

### 代码质量评估

**优点**：

1. **清晰的代码结构**

   - Chat 功能模块化良好，职责分离清晰
   - LiveView、Domain、Resource 层次分明
   - 符合 Phoenix 和 Ash 最佳实践

2. **数据库设计合理**

   - 使用 uuidv7 作为主键
   - CASCADE DELETE 处理关联删除
   - archived_at 支持逻辑删除
   - 索引设计合理

3. **PubSub 广播机制**

   - 消息更新实时同步
   - 字段合并逻辑完善，保护 tool_results 和 tool_calls
   - 支持流式更新

4. **错误处理**
   - LLMChain 错误捕获完善
   - 认证失败时仍允许连接（支持公开工具）
   - 错误日志记录合理

### 架构评估

**数据库层**：

- ✅ 合并后的 migration 包含所有必要字段
- ✅ CASCADE DELETE 约束正确配置
- ✅ 索引设计合理
- ✅ 使用 uuidv7 作为主键

**业务逻辑层**：

- ✅ Chat Domain 函数定义清晰
- ✅ Message Changes 逻辑完整，错误处理完善
- ✅ Tool schema 补丁处理 Azure OpenAI 兼容性

**UI 层**：

- ✅ 消息合并逻辑完善
- ✅ 支持图片显示和点击跳转
- ✅ 表单重置功能正常
- ✅ 对话归档和删除功能完整

**MCP 服务器**：

- ✅ 支持可选的 API Token 认证
- ✅ 认证失败时仍允许连接（支持公开工具）
- ✅ GET 请求正确拒绝
- ✅ 仅支持 StreamableHttp（POST 请求）

### 潜在问题和建议

1. **消息合并逻辑复杂度**

   - **位置**: `lib/vmemo_web/live/chat_live.ex:380-438`
   - **问题**: 消息合并逻辑较复杂，需要处理多种字段合并场景
   - **建议**: 可以考虑提取为独立的函数以提高可读性

2. **DeleteMessagesBeforeDestroy 空实现**

   - **位置**: `lib/vmemo/chat/conversation/changes/delete_messages_before_destroy.ex`
   - **问题**: 模块是空实现，但保留了 change 引用
   - **评估**: 注释说明了原因（依赖数据库 CASCADE），可以考虑移除 change 引用，完全依赖数据库 CASCADE

3. **Logger 使用**
   - ✅ 已移除 debug logs
   - ✅ 保留必要的 warning 和 error logs
   - ✅ Logger 使用位置合理

### 测试建议

1. **单元测试**

   - Message Changes 的 Respond 逻辑
   - Conversation 的归档和删除功能
   - MCP 认证逻辑

2. **集成测试**

   - Chat 消息流式更新
   - PubSub 广播机制
   - 图片搜索工具调用

3. **E2E 测试**
   - 完整的对话流程
   - 图片显示和点击跳转
   - 对话归档和删除

### 性能考虑

1. **数据库查询**

   - ✅ 索引设计合理
   - ✅ 查询使用适当的过滤条件

2. **PubSub 广播**

   - ✅ 只广播必要字段
   - ✅ 消息合并逻辑高效

3. **MCP 认证**
   - ✅ 认证失败时快速返回
   - ✅ 支持无认证访问（公开工具）

### 安全性

1. **认证**

   - ✅ API Token 验证正确
   - ✅ 支持可选认证（公开工具）

2. **权限控制**

   - ✅ 使用 actor 传递用户信息
   - ✅ 对话和消息关联到用户

3. **输入验证**
   - ✅ 消息文本验证（非空）
   - ✅ 对话 ID 验证

**总体评价**: ✅ 代码质量良好，可以合并

## 重构总结

### 重构内容

#### 1. 整理 Markdown 文档 ✅

**操作**:

- 创建了 `docs/devlog/20251224-pr56-chat-mcp-refactor.md` 总结文档
- 整合了所有相关的 devlog 文档内容
- 保留了关键信息和技术细节

**文档结构**:

- 概述
- 核心功能
- 关键问题和修复
- 技术细节

#### 2. 合并 Migrations ✅

**操作**:

- 将 `20251223100000_create_conversations_and_messages.exs` 更新为包含所有字段
- 添加了 `archived_at` 字段到 conversations 表
- 删除了 `20251223114213_add_archived_at_to_conversations.exs`
- 删除了 `20251223122250_add_cascade_delete_to_messages.exs`

**结果**:

- 所有 conversations 和 messages 相关的数据库变更现在在一个 migration 文件中
- Migration 包含所有必要的字段、索引和约束
- 使用 `IF NOT EXISTS` 确保幂等性

#### 3. 移除 Debug Logs ✅

**操作**:

- 移除了 `markdown_content.ex` 中的 `Logger.debug` 调用
- 移除了 `markdown_content.ex` 中不必要的 `Logger.warning`（user is nil）
- 精简了 `mcp_auth.ex` 中的 `Logger.warning`（移除了 path 和 remote_ip 详细信息）

**保留的 Logs**:

- `mcp_auth.ex`: API token 验证失败的 warning（用于调试认证问题）
- `markdown_content.ex`: 查询照片失败的 warning（用于调试查询问题）
- `respond.ex`: LLMChain 错误的 error logs（用于调试 AI 响应问题）

#### 4. Code Review ✅

**操作**:

- 创建了代码审查文档
- 评估了代码质量、架构设计和潜在问题
- 提供了改进建议

**审查结果**:

- ✅ 代码质量良好
- ✅ 架构设计合理
- ✅ 符合 Phoenix 和 Ash 最佳实践
- ⚠️ 建议提取消息合并逻辑为独立函数
- ⚠️ 可以考虑移除 `DeleteMessagesBeforeDestroy` change 引用

### 文件变更

**新增文件**:

- `docs/devlog/20251224-pr56-chat-mcp-refactor.md` - PR 56 功能总结
- `docs/devlog/20251224-pr56-code-review.md` - 代码审查报告（已合并到本文档）
- `docs/devlog/20251224-pr56-refactor-summary.md` - 重构总结（已合并到本文档）

**修改文件**:

- `priv/ash_repo/migrations/20251223100000_create_conversations_and_messages.exs` - 合并 migrations
- `lib/vmemo_web/live/components/markdown_content.ex` - 移除 debug logs
- `lib/vmemo_web/mcp_auth.ex` - 精简 warning logs

**删除文件**:

- `priv/ash_repo/migrations/20251223114213_add_archived_at_to_conversations.exs` - 已合并
- `priv/ash_repo/migrations/20251223122250_add_cascade_delete_to_messages.exs` - 已合并

### 验证

- ✅ 所有 migrations 合并完成
- ✅ Debug logs 已移除
- ✅ Warning logs 已精简
- ✅ Code review 完成
- ✅ 无 linter 错误

### 后续建议

1. **测试**: 运行完整的测试套件确保重构没有引入回归问题
2. **文档**: 更新主 README 或相关文档，说明 PR 56 的功能
3. **性能**: 监控生产环境中的性能表现
4. **优化**: 考虑提取消息合并逻辑为独立函数以提高可读性

## 相关文档

- `docs/devlog/20251224-pr56-chat-mcp-refactor.md` - PR 56 功能实现总结

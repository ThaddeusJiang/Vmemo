# 20251223 对话归档和删除功能实现

## 功能概述

实现了对话的归档（逻辑删除）和删除（物理删除）功能，包括：
- 在导航栏添加设置图标和下拉菜单
- 归档功能：设置 `archived_at` 时间戳，已归档对话不显示在列表中
- 删除功能：物理删除对话及其所有关联消息
- 成功/失败 toast 提示

## 技术实现

### 1. 数据库层

**迁移文件**：
- `20251223114213_add_archived_at_to_conversations.exs`：添加 `archived_at` 字段
- `20251223122250_add_cascade_delete_to_messages.exs`：添加 CASCADE 删除约束

**外键约束优化**：
- `messages_conversation_id_fkey`：设置为 `ON DELETE CASCADE`，删除 conversation 时自动删除所有 messages
- `messages_response_to_id_fkey`：设置为 `ON DELETE CASCADE`，处理自引用关系

### 2. 模型层

**Conversation 资源** (`lib/vmemo/chat/conversation.ex`)：
- 添加 `archived_at` 属性（类型：`utc_datetime`）
- 添加 `archive` action，使用 change 函数设置 `archived_at` 为当前时间
- 更新 `my_conversations` 查询，过滤已归档的对话（`is_nil(archived_at)`）
- `destroy` action 使用 `DeleteMessagesBeforeDestroy` change（已简化为空实现，依赖数据库 CASCADE）

**Message 资源** (`lib/vmemo/chat/message.ex`)：
- 在 `postgres` 配置中添加 `references`：
  ```elixir
  references do
    reference :conversation, on_delete: :delete
    reference :response_to, on_delete: :delete
  end
  ```
- 使用 AshPostgres 的 `on_delete: :delete` 配置，确保未来迁移自动生成正确的约束

### 3. Domain 层

**Chat Domain** (`lib/vmemo/chat.ex`)：
- 添加 `archive_conversation` 函数定义
- 添加 `delete_conversation` 函数定义（使用 `destroy` action）

### 4. UI 层

**ChatLive** (`lib/vmemo_web/live/chat_live.ex`)：
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

## 关键问题和解决方案

### 问题 1：`stream_delete` 参数错误
**错误**：`expected stream :conversations to be a struct or map with :id key, got: "conversation-id"`
**原因**：`stream_delete` 需要完整的 conversation 对象，而不是 ID
**解决**：修改代码使用完整的 `conversation` 对象，而不是 `conversation_id`

### 问题 2：删除消息时的外键约束错误
**错误**：删除 conversation 时，由于 messages 表的外键约束导致删除失败
**原因**：数据库外键约束设置为 `NO ACTION`，需要手动删除关联记录
**解决**：
1. 创建迁移文件，将外键约束改为 `ON DELETE CASCADE`
2. 在 `Message` 资源中添加 `references` 配置，使用 `on_delete: :delete`
3. 简化 `DeleteMessagesBeforeDestroy` change 模块，依赖数据库 CASCADE

### 问题 3：自引用关系的删除顺序
**问题**：messages 表有自引用关系（`response_to_id`），删除时需要先删除子消息
**解决**：数据库 CASCADE 会自动递归处理自引用关系，无需手动处理删除顺序

## 优化点

1. **使用数据库 CASCADE**：
   - 性能更好：数据库层面的级联删除比应用层删除更高效
   - 更可靠：数据库自动处理自引用关系的删除顺序
   - 代码更简洁：不需要手动管理删除顺序

2. **AshPostgres `references` 配置**：
   - 配置在代码中，版本可控
   - 未来运行 `mix ash_postgres.generate_migrations` 会自动生成正确的约束
   - 符合 Ash 最佳实践

3. **Toast 提示**：
   - 成功操作显示绿色 toast
   - 失败操作显示红色 toast
   - 提升用户体验

## 测试结果

- ✅ 归档功能正常工作：对话从列表中消失，显示成功 toast
- ✅ 删除功能正常工作：对话被物理删除，显示成功 toast
- ✅ 已归档的对话不会在列表中显示
- ✅ 删除 conversation 时，所有关联的 messages 被自动删除
- ✅ 自引用关系（response_to_id）的删除顺序由数据库自动处理

## 相关文件

- `lib/vmemo/chat/conversation.ex`
- `lib/vmemo/chat/message.ex`
- `lib/vmemo/chat/conversation/changes/delete_messages_before_destroy.ex`
- `lib/vmemo/chat.ex`
- `lib/vmemo_web/live/chat_live.ex`
- `priv/ash_repo/migrations/20251223114213_add_archived_at_to_conversations.exs`
- `priv/ash_repo/migrations/20251223122250_add_cascade_delete_to_messages.exs`


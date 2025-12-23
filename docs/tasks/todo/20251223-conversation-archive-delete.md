# 20251223 Conversation 归档和删除功能

## 任务目标

在对话列表的导航栏行尾添加一个设置图标，点击后显示菜单，菜单包含：
1. **归档**：逻辑删除，在数据库添加一个归档时间的列，UI 上不显示设置了归档时间的数据
2. **删除**：物理删除，删除对话的所有相关内容

## 计划阶段

### 需求分析

- 用户需要能够归档对话（逻辑删除）
- 用户需要能够删除对话（物理删除）
- 设置图标应该显示在导航栏行尾
- 点击后显示下拉菜单
- 已归档的对话不应该在 UI 中显示

### 技术方案

1. **数据库层**：
   - 添加 `archived_at` 字段到 `conversations` 表（类型：`utc_datetime`，可为空）

2. **模型层**：
   - 在 `Vmemo.Chat.Conversation` 中添加 `archived_at` 属性
   - 添加 `archive` action 用于设置 `archived_at`
   - 更新 `my_conversations` 查询，过滤掉已归档的对话（`archived_at IS NULL`）

3. **Domain 层**：
   - 在 `Vmemo.Chat` 中添加 `archive_conversation` 函数
   - 使用现有的 `destroy` action 进行物理删除

4. **UI 层**：
   - 在导航栏行尾添加设置图标（使用 heroicons，如 `hero-ellipsis-vertical`）
   - 使用 daisyUI 的 dropdown 组件显示菜单
   - 菜单包含"归档"和"删除"选项
   - 实现事件处理

### 任务分解

1. ✅ 创建数据库迁移：添加 `archived_at` 字段到 conversations 表
2. ✅ 更新 Conversation 模型：添加 `archived_at` 属性和归档 action
3. ✅ 更新 `my_conversations` 查询：过滤已归档的对话
4. ✅ 在 Chat domain 中添加归档和删除函数
5. ✅ 在导航栏添加设置图标和下拉菜单 UI
6. ✅ 实现归档和删除的事件处理
7. ✅ 测试归档和删除功能

## 执行记录

### 阶段一：数据库迁移

- **时间**：20251223
- **操作**：创建迁移文件 `20251223114213_add_archived_at_to_conversations.exs`，添加 `archived_at` 字段（类型：`utc_datetime`，可为空）
- **结果**：✅ 完成

### 阶段二：模型更新

- **时间**：20251223
- **操作**：
  - 在 `Vmemo.Chat.Conversation` 中添加 `archived_at` 属性
  - 添加 `archive` action，使用 change 函数设置 `archived_at` 为当前时间
  - 更新 `my_conversations` 查询，添加过滤条件 `is_nil(archived_at)`，确保已归档的对话不显示
  - 在 pub_sub 中添加 `archive` action 的发布配置
- **结果**：✅ 完成

### 阶段三：Domain 层更新

- **时间**：20251223
- **操作**：
  - 在 `Vmemo.Chat` domain 中添加 `archive_conversation` 函数定义
  - 添加 `delete_conversation` 函数定义（使用现有的 `destroy` action）
- **结果**：✅ 完成

### 阶段四：UI 实现

- **时间**：20251223
- **操作**：
  - 在导航栏行尾添加设置图标（使用 `hero-ellipsis-vertical`）
  - 使用 daisyUI 的 dropdown 组件显示菜单
  - 菜单包含两个选项：
    - "Archive"：使用 `hero-archive-box` 图标
    - "Delete"：使用 `hero-trash` 图标，文字颜色为 error
  - 设置图标只在有 conversation 时显示
- **结果**：✅ 完成

### 阶段五：事件处理

- **时间**：20251223
- **操作**：
  - 实现 `handle_event("archive_conversation", ...)`：
    - 获取 conversation
    - 调用 `Vmemo.Chat.archive_conversation` 归档对话
    - 从 stream 中删除该对话
    - 如果当前正在查看该对话，导航到 `/chat`
  - 实现 `handle_event("delete_conversation", ...)`：
    - 获取 conversation
    - 调用 `Vmemo.Chat.delete_conversation` 删除对话
    - 从 stream 中删除该对话
    - 如果当前正在查看该对话，导航到 `/chat`
- **结果**：✅ 完成

## 测试记录

- ✅ 已测试归档和删除功能
  - 运行迁移并测试功能
  - 测试归档功能：点击设置图标 → Archive，验证对话从列表中消失，显示 toast 提示
  - 测试删除功能：点击设置图标 → Delete，验证对话被物理删除，显示 toast 提示
  - 验证已归档的对话不会在 `my_conversations` 查询中显示
  - 修复了 `stream_delete` 使用完整 conversation 对象的问题
  - 优化了删除逻辑，使用数据库 CASCADE 自动删除关联消息

## 总结

- ✅ 数据库迁移已创建：`20251223114213_add_archived_at_to_conversations.exs`
- ✅ Conversation 模型已更新：
  - 添加 `archived_at` 属性（类型：`utc_datetime`）
  - 添加 `archive` action，设置 `archived_at` 为当前时间
  - 更新 `my_conversations` 查询，过滤已归档的对话（`is_nil(archived_at)`）
  - 添加 `archive` action 的 pub_sub 配置
- ✅ Chat domain 已更新：
  - 添加 `archive_conversation` 函数定义
  - 添加 `delete_conversation` 函数定义（使用 `destroy` action）
- ✅ UI 已实现：
  - 在导航栏行尾添加设置图标（`hero-ellipsis-vertical`）
  - 使用 daisyUI dropdown 组件显示菜单
  - 菜单包含"Archive"和"Delete"选项，带有相应图标
- ✅ 事件处理已实现：
  - `archive_conversation`：归档对话并从 stream 中删除，如果正在查看该对话则导航到 `/chat`，显示成功 toast
  - `delete_conversation`：删除对话并从 stream 中删除，如果正在查看该对话则导航到 `/chat`，显示成功 toast
- ✅ 已测试并优化：
  - 修复了 `stream_delete` 需要完整 conversation 对象的问题
  - 使用数据库 CASCADE 自动删除关联消息，简化删除逻辑
  - 在 `Message` 资源中添加 `references` 配置，设置 `on_delete: :delete`
  - 创建迁移文件添加 CASCADE 约束
  - 添加成功和失败的 toast 提示

## 代码变更总结

### 新增文件
- `priv/ash_repo/migrations/20251223114213_add_archived_at_to_conversations.exs`：添加 `archived_at` 字段
- `priv/ash_repo/migrations/20251223122250_add_cascade_delete_to_messages.exs`：添加 CASCADE 删除约束
- `lib/vmemo/chat/conversation/changes/delete_messages_before_destroy.ex`：删除消息的 change 模块（已简化为使用数据库 CASCADE）

### 修改文件
- `lib/vmemo/chat/conversation.ex`：
  - 添加 `archived_at` 属性
  - 添加 `archive` action，设置 `archived_at` 为当前时间
  - 更新 `my_conversations` 查询，过滤已归档的对话
  - 添加 `archive` action 的 pub_sub 配置
  - `destroy` action 使用 `DeleteMessagesBeforeDestroy` change（已简化）
- `lib/vmemo/chat/message.ex`：
  - 在 `postgres` 配置中添加 `references`，设置 `on_delete: :delete` 用于级联删除
- `lib/vmemo/chat.ex`：添加 `archive_conversation` 和 `delete_conversation` 函数定义
- `lib/vmemo_web/live/chat_live.ex`：
  - 添加设置图标和下拉菜单 UI
  - 实现 `archive_conversation` 和 `delete_conversation` 事件处理
  - 添加成功和失败的 toast 提示
  - 修复 `stream_delete` 使用完整 conversation 对象
  - 添加 `stream_configure` 配置

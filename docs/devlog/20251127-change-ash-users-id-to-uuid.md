# 2025-11-27 将 ash_users.id 改为 UUID 并启用自动生成

## 变更概述

将 `ash_users.id` 从 TEXT 类型改为 UUID 类型，并使用 Ash Postgres 的 `uuid_primary_key` 实现自动生成，与其他资源保持一致。

## 变更内容

### 代码变更

1. **`lib/vmemo/account/ash_user.ex`**

   - 将 `attribute :id, :string` 改为 `uuid_primary_key :id`
   - 移除手动生成 UUID 的代码（`generate_uuid/0` 函数和 `register` action 中的 change）
   - Ash 现在会自动生成 UUID

2. **更新所有资源的 `ash_user_id` 字段类型**
   - `lib/vmemo/photos/photo.ex`: `ash_user_id` 从 `:string` 改为 `:uuid`
   - `lib/vmemo/photos/note.ex`: `ash_user_id` 从 `:string` 改为 `:uuid`
   - `lib/vmemo/account/api_token.ex`: `ash_user_id` 从 `:string` 改为 `:uuid`
   - `lib/vmemo/account/ash_user_token.ex`: `ash_user_id` 从 `:string` 改为 `:uuid`，关系类型也更新

### 数据库迁移

**文件**: `priv/ash_repo/migrations/20251127224811_change_ash_users_id_to_uuid.exs`

**迁移步骤**:

1. 删除所有外键约束（`ash_user_tokens`、`api_tokens`、`photos`、`notes`）
2. 转换 `ash_users.id` 从 TEXT 到 UUID
   - 确保现有 ID 是有效的 UUID 格式
   - 设置默认值 `uuid_generate_v7()`
3. 转换所有外键字段类型（`ash_user_id` 从 TEXT 到 UUID）
4. 重新创建外键约束

**特点**:

- 安全的数据转换：确保现有 ID 是有效的 UUID 格式
- 完整的回滚支持（`down` 函数）
- 处理外键约束的删除和重建

## 影响

### 优势

- ✅ **代码简化**：移除手动生成 UUID 的代码
- ✅ **一致性**：与其他资源（Photo、Note、ApiToken）保持一致
- ✅ **自动生成**：Ash Postgres 自动处理 UUID 生成
- ✅ **类型安全**：使用 UUID 类型而不是字符串

### 注意事项

- ⚠️ 数据库迁移已执行，所有现有数据已转换
- ⚠️ 所有外键字段类型已更新为 UUID

## 验证

- ✅ 迁移成功执行
- ✅ UUID 自动生成功能正常
- ✅ UUID 格式验证通过

## 相关任务

- [任务文档](tasks/todo/2025-11-27-analyze-secret-key-merge.md)

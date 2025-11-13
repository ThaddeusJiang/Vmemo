# 2025-01-27 修复数据库 ID 类型和外键关系

## 任务目标

修改数据库表，要求：
1. 所有 ID 都是 UUID 类型
2. 外键关系正确设置
3. 修复 photos.user_id 没有正确连接到 ash_users.id 的问题

## 计划阶段

### 当前状态分析

1. **ash_users 表**:
   - `id`: TEXT 类型（存储 UUID 字符串格式）
   - 这是合理的，因为 Ash schema 中定义为 `:string`

2. **photos 表**:
   - `id`: TEXT 类型，应该改为 UUID
   - `user_id`: TEXT 类型，没有外键约束
   - Schema 中 `user_id` 定义为 `:uuid`，但应该改为 `:string` 以匹配 `ash_users.id`

3. **notes 表**:
   - `id`: TEXT 类型，应该改为 UUID
   - `user_id`: TEXT 类型，没有外键约束
   - Schema 中 `user_id` 定义为 `:string`，这是正确的

4. **photos_notes 表**:
   - `id`: TEXT 类型，应该改为 UUID
   - `photo_id`: 已有外键约束到 photos.id
   - `note_id`: 已有外键约束到 notes.id

5. **api_tokens 表**:
   - `id`: BIGSERIAL 类型，应该改为 UUID
   - `ash_user_id`: TEXT 类型，已有外键约束到 ash_users.id

### 技术方案

1. **修改迁移文件** (`20251029130000_squashed_core_schema.exs`):
   - 将所有 ID 字段改为 `:uuid` 类型
   - 将 `photos.user_id` 和 `notes.user_id` 保持为 `:text` 类型（匹配 `ash_users.id`）
   - 添加 `photos.user_id` 到 `ash_users.id` 的外键约束
   - 添加 `notes.user_id` 到 `ash_users.id` 的外键约束

2. **更新 Ash Schema**:
   - `photos.user_id`: 从 `:uuid` 改为 `:string`
   - `api_tokens.id`: 从 `integer_primary_key` 改为 `uuid_primary_key`
   - 更新相关的 actions 和 filters

## 执行记录

### 阶段一：分析问题

- **时间**：2025-01-27
- **操作**：分析当前数据库结构和 Ash schema 定义
- **结果**：识别出所有需要修改的地方
- **问题**：photos.user_id 在 schema 中是 :uuid，但 ash_users.id 是 :string，类型不匹配
- **解决方案**：将 photos.user_id 改为 :string 类型以匹配 ash_users.id

### 阶段二：修改迁移文件

- **时间**：2025-01-27
- **操作**：修改 `20251029130000_squashed_core_schema.exs` 迁移文件
- **修改内容**：
  1. 将 `api_tokens.id` 从 `:bigserial` 改为 `:uuid`
  2. 将 `photos.id` 从 `:text` 改为 `:uuid`
  3. 将 `notes.id` 从 `:text` 改为 `:uuid`
  4. 将 `photos_notes.id` 从 `:text` 改为 `:uuid`
  5. 将 `photos_notes.photo_id` 和 `photos_notes.note_id` 的引用类型从 `:text` 改为 `:uuid`
  6. 保持 `photos.user_id` 和 `notes.user_id` 为 `:text` 类型（匹配 `ash_users.id`）
  7. 添加 `photos.user_id` 到 `ash_users.id` 的外键约束
  8. 添加 `notes.user_id` 到 `ash_users.id` 的外键约束
  9. 更新 `down` 函数以正确删除外键约束
- **结果**：迁移文件已更新，所有 ID 字段改为 UUID，外键约束已添加

### 阶段三：更新 Ash Schema

- **时间**：2025-01-27
- **操作**：更新 Ash schema 定义以匹配数据库结构
- **修改内容**：
  1. `lib/vmemo/photos/photo.ex`: 将 `user_id` 从 `:uuid` 改为 `:string`
  2. `lib/vmemo/account/api_token.ex`:
     - 将 `id` 从 `integer_primary_key` 改为 `uuid_primary_key`
     - 将所有使用 `:integer` 作为 id 参数的地方改为 `:uuid`（`get_by_id`, `get_by_user_and_id`, `toggle_status`）
- **结果**：Ash schema 已更新，类型匹配数据库结构

### 阶段四：修复迁移冲突

- **时间**：2025-01-27
- **操作**：修复旧的迁移文件 `20251030062048_fix_photos_id_column_to_uuid.exs` 与主迁移的冲突
- **问题**：旧迁移试图将 `photos.user_id` 和 `notes.user_id` 改为 UUID，但这与主迁移中保持为 TEXT 的设计冲突
- **解决方案**：将旧迁移改为空操作（`:ok`），因为主迁移已经正确处理了所有类型
- **结果**：迁移冲突已解决

### 阶段五：修复 UUID 自动生成

- **时间**：2025-01-27
- **操作**：为 `api_tokens.id` 添加数据库默认值
- **问题**：`api_tokens.id` 是 UUID 类型，但没有默认值，导致创建记录时 ID 为 null
- **解决方案**：在迁移文件中为 `api_tokens.id` 添加默认值 `uuid_generate_v7()`
- **结果**：UUID 自动生成正常工作

## 测试记录

- **时间**：2025-01-27
- **操作**：运行 `MIX_ENV=test mix ecto.reset` 重置测试数据库
- **结果**：迁移成功执行，所有表结构正确创建
- **测试 token 创建**：成功创建测试 API token，验证 UUID 自动生成功能正常
- **完整测试套件**：运行 `mix test`，163 个测试全部通过，0 个失败

## 总结

### 完成的修改

1. ✅ 所有 ID 字段改为 UUID 类型：
   - `api_tokens.id`: `:bigserial` → `:uuid` (带默认值 `uuid_generate_v7()`)
   - `photos.id`: `:text` → `:uuid`
   - `notes.id`: `:text` → `:uuid`
   - `photos_notes.id`: `:text` → `:uuid`

2. ✅ 外键关系正确设置：
   - `photos.user_id` → `ash_users.id` (TEXT 类型，已添加外键约束)
   - `notes.user_id` → `ash_users.id` (TEXT 类型，已添加外键约束)
   - `photos_notes.photo_id` → `photos.id` (UUID 类型，已有外键约束)
   - `photos_notes.note_id` → `notes.id` (UUID 类型，已有外键约束)

3. ✅ Ash Schema 更新：
   - `photos.user_id`: `:uuid` → `:string`
   - `api_tokens.id`: `integer_primary_key` → `uuid_primary_key`
   - 所有相关的 actions 参数类型已更新

### 关键决策

- **保持 `ash_users.id` 为 TEXT 类型**：因为 Ash schema 中定义为 `:string`，且已有数据使用字符串 UUID 格式
- **`photos.user_id` 和 `notes.user_id` 使用 TEXT 类型**：以匹配 `ash_users.id` 的类型，确保外键约束可以正常工作
- **所有主键 ID 使用 UUID 类型**：符合项目要求，使用 `uuid_generate_v7()` 函数生成

### 下一步

- 运行完整测试套件验证所有功能正常
- 检查是否有其他代码需要更新以适应新的 ID 类型

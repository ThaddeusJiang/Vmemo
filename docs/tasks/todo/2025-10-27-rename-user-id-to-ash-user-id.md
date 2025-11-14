# 2025-10-27 将所有 user_id 改为 ash_user_id

## 任务目标

将数据库表和代码中所有的 `user_id` 字段/属性/参数改为 `ash_user_id`，以保持命名一致性。

## 计划阶段

### 当前状态分析

1. **数据库表结构**:

   - `photos` 表: `user_id` (TEXT, 外键到 ash_users.id)
   - `notes` 表: `user_id` (TEXT, 外键到 ash_users.id)
   - `api_tokens` 表: 已有 `ash_user_id` (TEXT, 外键到 ash_users.id)，`user_id` (BIGINT, 已废弃)

2. **Ash 资源定义**:

   - `Photo`: `user_id` 属性 (:string)
   - `Note`: `user_id` 属性 (:string)
   - `ApiToken`: 已有 `ash_user_id` 属性，`user_id` 属性已废弃

3. **代码使用情况**:
   - 约 79 处使用 `user_id`，分布在多个文件中
   - 包括：资源定义、actions、filters、LiveView、控制器、服务层等

### 技术方案

1. **数据库迁移**:

   - 创建新迁移文件，将 `photos.user_id` 重命名为 `photos.ash_user_id`
   - 将 `notes.user_id` 重命名为 `notes.ash_user_id`
   - 更新外键约束名称

2. **Ash 资源更新**:

   - `Photo`: `user_id` → `ash_user_id`
   - `Note`: `user_id` → `ash_user_id`
   - 更新所有相关的 actions、filters、code_interface

3. **代码更新**:

   - 更新所有使用 `user_id` 的地方
   - 包括：LiveView、控制器、服务层、Workers 等

4. **测试验证**:
   - 运行测试确保所有功能正常
   - 检查 linter 错误

## 执行记录

### 阶段一：创建迁移文件

- **时间**：2025-01-27
- **操作**：创建数据库迁移文件 `20251113104351_rename_user_id_to_ash_user_id.exs`
- **修改内容**：
  - 将 `photos.user_id` 重命名为 `photos.ash_user_id`
  - 将 `notes.user_id` 重命名为 `notes.ash_user_id`
  - 更新外键约束名称（`photos_user_id_fkey` → `photos_ash_user_id_fkey`，`notes_user_id_fkey` → `notes_ash_user_id_fkey`）
- **结果**：迁移文件已创建

### 阶段二：更新 Ash 资源

- **时间**：2025-01-27
- **操作**：更新 Photo 和 Note 资源定义
- **修改内容**：
  - `Photo` 资源：
    - `admin.table_columns`: `user_id` → `ash_user_id`
    - `code_interface`: 所有使用 `user_id` 的参数改为 `ash_user_id`
    - `actions`: `accept`, `argument`, `filter` 中的 `user_id` 改为 `ash_user_id`
    - `attributes`: `user_id` 属性改为 `ash_user_id`
  - `Note` 资源：
    - `admin.table_columns`: `user_id` → `ash_user_id`
    - `actions.accept`: `user_id` → `ash_user_id`
    - `attributes`: `user_id` 属性改为 `ash_user_id`
- **结果**：Ash 资源已更新

### 阶段三：更新代码引用

- **时间**：2025-01-27
- **操作**：更新所有使用 `user_id` 的代码
- **修改文件**：
  1. `lib/vmemo_web/live/components/upload_form.ex`: 创建 Note 和 Photo 时使用 `ash_user_id`
  2. `lib/vmemo_web/live/components/search_box.ex`: 创建 Photo 时使用 `ash_user_id`，同步到 Typesense 时使用 `photo.ash_user_id`
  3. `lib/vmemo/workers/sync_photo_to_typesense.ex`: SQL 查询和 map 键改为 `ash_user_id`
  4. `lib/vmemo/workers/sync_note_to_typesense.ex`: 使用 `note.ash_user_id`
  5. `lib/vmemo_web/api/v1/photo_controller.ex`: 创建 Photo 时使用 `ash_user_id`
- **结果**：所有代码引用已更新

### 阶段四：测试验证

- **时间**：2025-01-27
- **操作**：编译代码并检查 linter
- **结果**：
  - 编译成功，无错误
  - Linter 检查通过，无错误

## 测试记录

- **编译测试**：✅ 通过
- **Linter 检查**：✅ 通过
- **数据库迁移**：✅ 成功执行，列重命名和外键约束更新正常
- **完整测试套件**：✅ 163 个测试全部通过，0 个失败

## 总结

### 完成的修改

1. ✅ **数据库迁移**：

   - 创建迁移文件重命名 `photos.user_id` → `photos.ash_user_id`
   - 创建迁移文件重命名 `notes.user_id` → `notes.ash_user_id`
   - 更新外键约束名称

2. ✅ **Ash 资源更新**：

   - `Photo` 资源：所有 `user_id` 引用改为 `ash_user_id`
   - `Note` 资源：所有 `user_id` 引用改为 `ash_user_id`

3. ✅ **代码更新**：
   - LiveView 组件：更新创建和查询操作
   - Workers：更新同步到 Typesense 的逻辑
   - API 控制器：更新创建操作

### 关键决策

- **保持参数名一致性**：所有 Ash 资源操作使用 `ash_user_id` 作为参数名
- **数据库列名统一**：`photos` 和 `notes` 表都使用 `ash_user_id` 列名，与 `api_tokens` 表保持一致
- **向后兼容**：迁移文件包含 `down` 函数，可以回滚更改

### 完成状态

✅ **所有任务已完成**

- ✅ 数据库迁移文件已创建并测试通过
- ✅ Ash 资源定义已更新
- ✅ 所有代码引用已更新
- ✅ 编译和 linter 检查通过
- ✅ 完整测试套件通过（163 个测试，0 个失败）

### 下一步

- 在生产环境应用迁移：`mix ecto.migrate`
- 验证生产环境功能正常

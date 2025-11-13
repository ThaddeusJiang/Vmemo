# 2025-01-27 将所有 user_id 改为 ash_user_id

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
- **操作**：创建数据库迁移文件，重命名列并更新外键约束
- **结果**：待执行

### 阶段二：更新 Ash 资源

- **时间**：2025-01-27
- **操作**：更新 Photo 和 Note 资源定义
- **结果**：待执行

### 阶段三：更新代码引用

- **时间**：2025-01-27
- **操作**：更新所有使用 user_id 的代码
- **结果**：待执行

### 阶段四：测试验证

- **时间**：2025-01-27
- **操作**：运行测试和 linter
- **结果**：待执行

## 测试记录

- 待执行

## 总结

- 待完成


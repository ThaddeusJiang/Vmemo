# 修复 API Token 使用追踪

## 问题

发现 API Token 的 `last_used_at` 和 `usage_count` 显示不准确：
- `last_used_at` 显示为 "Never used"，但实际可能已经使用过
- `usage_count` 硬编码为 0，完全没有统计功能

## 根本原因

1. **last_used_at 更新问题**：
   - `update_last_used_at` 函数没有检查返回值，如果更新失败也不会报错
   - 没有错误日志，无法知道更新是否成功

2. **usage_count 缺失**：
   - ApiToken 模型中没有 `usage_count` 字段
   - 数据库表中也没有该字段
   - UI 中硬编码为 0

## 解决方案

### 1. 修复 last_used_at 更新逻辑

- 重命名 `update_last_used_at` 为 `update_token_usage`
- 添加错误处理和日志记录
- 同时更新 `last_used_at` 和 `usage_count`

### 2. 实现 usage_count 统计

- 在 ApiToken 模型中添加 `usage_count` 字段（integer，默认 0）
- 在 update action 中接受 `usage_count` 和 `last_used_at`
- 创建数据库迁移添加 `usage_count` 列
- 在 `verify_api_token` 中每次验证时增加计数

### 3. 更新 UI 显示

- 修改 `index.ex` 和 `show.ex` 中的 Usage Count 显示，从硬编码的 0 改为显示 `token.usage_count || 0`

## 变更

### 修改的文件

1. `lib/vmemo/api_token_service.ex`
   - 修复 `update_token_usage` 函数，添加错误处理
   - 在验证 token 时同时更新 `last_used_at` 和 `usage_count`

2. `lib/vmemo/account/api_token.ex`
   - 添加 `usage_count` 属性（integer，默认 0）
   - 在 update action 中接受 `last_used_at` 和 `usage_count`

3. `lib/vmemo_web/live/api_token_live/index.ex`
   - 更新 Usage Count 列显示真实数据

4. `lib/vmemo_web/live/api_token_live/show.ex`
   - 更新 Usage Count 显示真实数据

### 创建的文件

1. `priv/ash_repo/migrations/20251224121701_add_usage_count_to_api_tokens.exs`
   - 添加 `usage_count` 字段到 `api_tokens` 表

## 测试

迁移已成功运行，数据库字段已正确添加：
- `usage_count`: bigint, default 0
- `last_used_at`: timestamp (已存在)

所有现有 token 的 `usage_count` 初始化为 0，这是正确的。

## 后续步骤

当 API token 被使用时（通过 `verify_api_token`），系统会：
1. 更新 `last_used_at` 为当前时间
2. 增加 `usage_count` 计数
3. 如果更新失败，会记录错误日志

UI 会显示真实的统计数据。

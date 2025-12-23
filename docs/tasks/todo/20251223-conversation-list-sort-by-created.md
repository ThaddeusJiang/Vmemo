# 20251223 对话列表默认按创建时间排序

## 任务目标

- 修改对话列表查询，默认按 `inserted_at`（创建时间）排序，而不是 `updated_at`
- 更新 UI 指南文档，添加列表排序规则

## 计划阶段

### 需求分析
- 当前对话列表可能按 `updated_at` 排序（或没有明确排序）
- 用户希望列表永远默认采用 `created`（`inserted_at`）排序
- UI 使用了 `flex-col-reverse`，需要考虑排序方向

### 技术方案
1. 在 `my_conversations` action 中添加默认排序
   - 参考 `message_history` 的实现方式
   - 可以在 action 中使用 `prepare build(default_sort: [inserted_at: :desc])`
   - 或者在 domain 定义中添加 `default_options: [query: [sort: [inserted_at: :desc]]]`
2. 更新 UI 指南文档，添加列表排序规则说明

### 风险评估
- 低风险：只是修改排序逻辑，不影响其他功能

## 执行记录

### 阶段一：修改排序逻辑

- **时间**：20251223
- **操作**：修改 `my_conversations` action，添加按 `inserted_at` 排序
- **结果**：✅ 完成
  - 在 `lib/vmemo/chat/conversation.ex` 的 `my_conversations` action 中添加了 `prepare build(default_sort: [inserted_at: :desc])`
- **问题**：无
- **解决方案**：无

### 阶段二：更新 UI 指南文档

- **时间**：20251223
- **操作**：更新 `docs/ui/ui-guidelines.md`，添加列表排序规则
- **结果**：✅ 完成
  - 添加了 List 章节，说明列表默认按 `inserted_at` 排序
- **问题**：无
- **解决方案**：无

## 测试记录

- ✅ 代码修改完成，无 linter 错误
- ⏳ 需要在实际运行环境中验证列表排序是否正确

## 总结

- ✅ 已完成对话列表默认按创建时间排序的修改
- ✅ 已更新 UI 指南文档，添加列表排序规则
- 📝 修改位置：
  - `lib/vmemo/chat/conversation.ex`：在 `my_conversations` action 中添加了 `prepare build(default_sort: [inserted_at: :desc])`
  - `docs/ui/ui-guidelines.md`：添加了 List 章节说明排序规则

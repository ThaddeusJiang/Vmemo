## Main User Story

- [ ] **测试 user_id 类型转换**：旧代码显式调用 `Integer.to_string()` 转换 user_id，新代码直接传递整数。虽然测试通过，但需要验证在实际使用中是否会出现类型不匹配问题（特别是在 Typesense 查询时）

重要‼️
- [ ] 在发布请版本前，一定要保证已有 user 和 photo 完整

- [ ] **验证照片详情页表单行为**：表单中 `_gen_description` 字段现在硬编码为 `nil`，之前是从 `photo._gen_description` 读取。需要确认：
  - AI 生成的描述是否仍能正常保存和显示
  - 这是否是故意的设计变更（因为 Ash Photo resource 可能还没有这个字段）

- [ ] **测试完整的照片流程**：
  - 上传照片 → 搜索照片 → 查看详情 → 编辑笔记 → 删除照片
  - 相似照片推荐功能
  - AI 描述生成功能

- [ ] **测试错误场景**：
  - 访问不存在的照片 ID（应该显示空状态而不是崩溃）
  - Postgres 和 Typesense 数据不同步的情况（例如刚上传的照片还未同步到 Typesense）

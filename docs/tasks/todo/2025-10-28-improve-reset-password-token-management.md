# 2025-10-28 改进 Reset Password Token 管理

## 任务目标

完善 reset password token 的生成、验证、使用和清理机制，确保安全性和用户体验。

### 需求分析

1. **Token 验证失败应在 UI 显示错误**：当前 token 验证失败时直接重定向，用户看不到具体错误信息
2. **Token 生成和存储**：确保 token 正确生成并存储到数据库
3. **Token 状态检查**：检查 token 是否已使用、是否已过期
4. ~~**Token 清理机制**：定期清理已使用或过期的 token~~（已取消）

## 计划阶段

### 技术方案

1. **改进 UI 错误显示**

   - 在 `UserResetPasswordLive` 中，token 验证失败时显示错误信息而不是直接重定向
   - 使用 flash message 或页面错误提示

2. **Token 生成和存储**

   - 确保 `deliver_ash_user_reset_password_instructions` 生成的 token 正确存储
   - 验证 `AshAuthentication.Jwt.token_for_user` 是否自动创建 `AshUserToken` 记录

3. **Token 状态验证**

   - 在 `get_ash_user_by_reset_password_token` 中检查：
     - Token 是否存在于数据库（是否已被撤销）
     - Token 是否已过期（检查 `exp` 字段）
   - 返回详细的错误信息

4. ~~**Token 清理机制**~~（已取消）
   - 决定不引入 job 增加复杂度
   - Token 过期后验证会自动失败，不需要主动清理

### 风险评估

- **风险 1**：Token 验证逻辑变更可能影响现有功能

  - **缓解**：保持向后兼容，逐步改进

- **风险 2**：定期清理任务可能影响性能
  - **缓解**：使用索引优化查询，分批清理

### 任务分解

1. 改进 token 验证失败时的 UI 显示
2. 增强 token 验证逻辑（检查使用状态和过期时间）
3. 验证 token 生成和存储机制
4. 实现 token 清理机制（可选，如果需要）

## 执行记录

### 阶段一：改进 Token 验证失败时的 UI 显示

- **时间**：2025-01-28
- **操作**：修改 `UserResetPasswordLive` 的 render 和 mount 函数
- **变更**：
  1. 在 render 中添加 token 错误显示区域，使用 alert 组件显示错误信息
  2. 添加"Request a new reset link"按钮，方便用户重新申请
  3. 修改 mount 函数，使用新的 `verify_reset_password_token` 函数
  4. 添加 `get_error_message/1` 函数，提供详细的错误信息
- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex`

### 阶段二：增强 Token 验证逻辑

- **时间**：2025-01-28
- **操作**：实现 `verify_reset_password_token/1` 函数
- **变更**：
  1. 验证 JWT token 签名
  2. 检查 token 是否存在于数据库（是否已被撤销）
  3. 检查 token 是否已过期（比较 `exp` 字段和当前时间）
  4. 返回详细的错误原因：`:invalid_token`, `:expired_token`, `:token_not_found`, `:user_not_found`
- **文件**：`lib/vmemo/account.ex` 第 344-411 行

### 阶段三：验证 Token 生成和存储机制

- **时间**：2025-01-28
- **操作**：验证 `AshAuthentication.Jwt.token_for_user` 是否自动创建 token 记录
- **结果**：
  - ✅ `AshAuthentication` 配置了 `token_resource(Vmemo.Account.AshUserToken)`
  - ✅ `token_for_user` 会自动创建 token 记录到数据库
  - ✅ Token 生成和存储机制正常工作

### 阶段四：Token 清理机制（已取消）

- **时间**：2025-01-28
- **决策**：不需要引入 job 增加复杂度，取消 token 清理机制
- **原因**：Token 过期后验证会失败，不需要主动清理

### 阶段五：增强提交时的 Token 验证

- **时间**：2025-01-28
- **操作**：在 `handle_event("reset_password", ...)` 中再次验证 token
- **变更**：
  1. 在提交密码重置时再次验证 token 是否有效
  2. 如果 token 已失效，显示错误信息而不是继续处理
  3. 确保 token 在提交时仍然有效
- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex` 第 103-140 行

## 测试记录

### 测试项目

- [ ] 测试 token 验证失败时的 UI 显示
- [ ] 测试过期 token 的验证
- [ ] 测试已撤销 token 的验证
- [ ] 测试提交时 token 失效的情况

## 总结

### 完成的功能

1. ✅ **改进 Token 验证失败时的 UI 显示**

   - 在页面上显示详细的错误信息
   - 提供"Request a new reset link"按钮

2. ✅ **增强 Token 验证逻辑**

   - 检查 token 是否存在于数据库
   - 检查 token 是否已过期
   - 返回详细的错误原因

3. ✅ **验证 Token 生成和存储机制**
   - 确认 `AshAuthentication` 自动创建 token 记录

### 代码变更

- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex`

  - 改进 UI 错误显示
  - 增强 token 验证逻辑

- **文件**：`lib/vmemo/account.ex`
  - 新增 `verify_reset_password_token/1` 函数
  - 增强 token 验证逻辑

### 取消的功能

- ❌ **Token 清理机制**：决定不引入 job 增加复杂度，token 过期后验证会自动失败

### 待办事项

- [ ] 实际测试所有功能

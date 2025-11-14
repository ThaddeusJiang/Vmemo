# 2025-11-14 修复 Reset Password 链接问题

## 任务目标

修复通过邮件发送的 reset-password 链接无法使用的问题。

## 问题分析

### 发现的问题

1. **Token 生成和验证不匹配**：

   - `deliver_ash_user_reset_password_instructions/2` 生成的是随机 base64 编码字符串
   - `get_ash_user_by_reset_password_token/1` 期望的是 JWT token，使用 `AshAuthentication.Jwt.verify` 验证
   - 两者不匹配导致 token 验证失败

2. **代码位置**：
   - `lib/vmemo/account.ex` 第 303-312 行：生成 token
   - `lib/vmemo/account.ex` 第 326-347 行：验证 token

## 计划阶段

### 解决方案

使用 `AshAuthentication.Jwt.token_for_user` 生成 JWT token，与验证逻辑保持一致。

### 技术方案

1. 修改 `deliver_ash_user_reset_password_instructions/2`，使用 `AshAuthentication.Jwt.token_for_user` 生成 JWT token
2. 确保生成的 token 可以被 `get_ash_user_by_reset_password_token/1` 正确验证
3. 测试修复后的功能

## 执行记录

### 阶段一：修复 Token 生成逻辑

- **时间**：2025-01-28
- **操作**：修改 `deliver_ash_user_reset_password_instructions/2` 函数
- **变更**：使用 `AshAuthentication.Jwt.token_for_user` 替代随机 base64 字符串
- **文件**：`lib/vmemo/account.ex` 第 303-323 行

### 阶段二：修复参数处理

- **时间**：2025-01-28
- **操作**：在 `UserResetPasswordLive` 中添加缺少 token 的处理
- **变更**：添加 `assign_user_and_token/2` 的默认匹配子句
- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex` 第 85-89 行

## 测试记录

### 测试结果

- **时间**：2025-01-28
- **测试内容**：验证 token 生成和验证逻辑是否匹配
- **结果**：
  - ✅ Token 生成成功（使用 `AshAuthentication.Jwt.token_for_user`）
  - ✅ Token 验证成功（使用 `get_ash_user_by_reset_password_token`）
  - ✅ 生成的 JWT token 可以被正确验证

### 注意事项

用户提供的旧链接中的 token 是使用旧的随机 base64 生成方式创建的，无法被新的验证逻辑验证。用户需要：

1. 重新发送 reset password 邮件
2. 使用新邮件中的链接来重置密码

## 修复记录（第二次）

### 问题

- **错误**：`Protocol.UndefinedError: protocol Phoenix.HTML.FormData not implemented for Ash.Changeset`
- **原因**：`to_form/2` 不能直接处理 `Ash.Changeset`，需要使用 `AshPhoenix.Form` 来创建表单

### 修复方案

- **时间**：2025-01-28
- **操作**：将 `UserResetPasswordLive` 改为使用 `AshPhoenix.Form` 处理表单
- **变更**：
  1. 在 `mount/3` 中使用 `AshPhoenix.Form.for_update(user, :reset_password)` 创建表单
  2. 在 `handle_event("validate", ...)` 中使用 `AshPhoenix.Form.validate` 验证表单
  3. 在 `handle_event("reset_password", ...)` 中使用 `AshPhoenix.Form.submit` 提交表单
  4. 表单参数从 `%{"user" => user_params}` 改为 `%{"form" => form_params}`
- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex`

### 修复方案（第三次）

- **时间**：2025-01-28
- **错误**：`BadMapError: expected a map, got: nil` 在 `handle_event("validate", ...)` 中
- **原因**：`temporary_assigns: [form: nil]` 导致 form 在每次渲染后被重置为 nil，当 validate 事件触发时，`socket.assigns.form` 可能是 nil
- **修复**：
  1. 将 `temporary_assigns: [form: nil]` 改为 `temporary_assigns: [form: form]`，使用初始 form 值作为重置值
  2. 添加 `get_form_source/1` 辅助函数，安全地获取 form source，如果 form 不存在或为 nil，则重新创建
  3. 在 `validate` 和 `reset_password` 事件处理中使用 `get_form_source` 而不是直接访问 `socket.assigns.form.source`
- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex`

### 修复方案（第四次）：简化代码逻辑

- **时间**：2025-01-28
- **需求**：简化 `UserResetPasswordLive` 的逻辑，使其更易维护
- **变更**：
  1. 移除复杂的 `AshPhoenix.Form` 处理逻辑
  2. 移除 `validate` 事件处理，合并到 `reset_password` 中
  3. 使用简单的 `to_form` 和 map 处理表单
  4. 添加简单的密码验证函数 `validate_password/1`
  5. 代码从 136 行简化到约 111 行
- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex`

### 修复方案（第五次）：实现 Token 撤销功能

- **时间**：2025-01-28
- **需求**：使用 token 重置密码后，使 token 失效，避免重复使用
- **实现**：
  1. 在 `mount/3` 中保存 token 到 socket assigns
  2. 添加 `revoke_reset_password_token/1` 函数：
     - 验证 token 并提取 `jti` (JWT ID)
     - 查找对应的 `AshUserToken` 记录
     - 删除该记录，使 token 失效
  3. 在成功重置密码后调用 `revoke_reset_password_token`
- **安全效果**：
  - 每个 reset password token 只能使用一次
  - 即使 token 被泄露，使用后也会失效
  - 防止重复使用同一个 token 重置密码
- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex` 第 115-134 行

## 总结

### 完成的功能

1. ✅ **修复 Token 生成和验证不匹配问题**

   - 使用 `AshAuthentication.Jwt.token_for_user` 生成 JWT token
   - 确保 token 可以被正确验证

2. ✅ **修复表单处理问题**

   - 从复杂的 `AshPhoenix.Form` 改为简单的 `to_form` 处理
   - 简化代码逻辑，提高可维护性

3. ✅ **实现 Token 撤销功能**
   - 重置密码成功后自动撤销 token
   - 确保每个 token 只能使用一次

### 最终代码结构

- **文件**：`lib/vmemo_web/live/user_reset_password_live.ex` (136 行)
- **主要函数**：
  - `mount/3`: 验证 token 并初始化表单
  - `handle_event("reset_password", ...)`: 验证密码并重置，成功后撤销 token
  - `validate_password/1`: 简单的密码验证逻辑
  - `revoke_reset_password_token/1`: 撤销 token 功能

### 测试状态

- ✅ 代码通过 linter 检查
- ✅ Token 生成和验证逻辑匹配
- ✅ 表单处理正常工作
- ⚠️ 需要实际测试 token 撤销功能

### 待办事项

- [ ] 实际测试 token 撤销功能是否正常工作
- [ ] 测试使用已撤销的 token 是否会被拒绝

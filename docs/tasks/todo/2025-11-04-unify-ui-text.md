# 2025-11-04 统一 UI 文案

## 任务目标

将 UI 中的认证相关文案统一为：
- Sign in → Login
- Sign up → Register
- Sign out → Logout
- Signed out → Logged out
- Create account → Register

## 计划阶段

### 需要修改的文件类型
1. LiveView 模板
2. Layout 文件
3. Controller 提示信息
4. 测试文件中的断言文本

### 文案映射
- "Sign in" → "Login"
- "sign in" → "login"
- "Sign up" → "Register"
- "sign up" → "register"
- "Sign out" → "Logout"
- "Signed out" → "Logged out"
- "Create your account" → "Register your account"
- "Create Account" → "Register"

## 执行记录

### 阶段一：查找所有包含这些文案的文件

**时间**：2025-11-04

**操作**：使用 `grep` 查找所有包含 sign in/sign up/sign out 的文件

**结果**：找到 20 处需要修改的地方，分布在：
- LiveView 文件（7个文件）
- Layout 文件
- Auth 模块
- 测试文件

### 阶段二：批量修改 UI 文案

**操作**：
1. 手动修改 LiveView 文件中的文案
2. 手动修改 Layout 和 Auth 模块中的提示信息
3. 使用 `sed` 批量修改测试文件中的断言

**修改映射**：
- "Sign in" → "Login"
- "sign in" → "login"
- "Sign up" → "Register"
- "sign up" → "register"
- "Sign out" → "Logout"
- "Signed out" → "Logged out"
- "Create your account" → "Register your account"
- "Create Account" → "Register"

**结果**：✅ 所有文案统一修改完成

## 测试记录

**编译检查**：✅ 通过，无错误

**单元测试**：✅ 全部通过
```bash
mix test test/vmemo_web/live/user_login_live_test.exs test/vmemo_web/live/user_registration_live_test.exs
# 12 tests, 0 failures
```

## 总结

### 修改的文件（共 18 个）

**LiveView 文件**：
1. `lib/vmemo_web/live/user_session_live.ex`
2. `lib/vmemo_web/live/user_registration_live.ex`
3. `lib/vmemo_web/live/user_login_live.ex`
4. `lib/vmemo_web/live/user_forgot_password_live.ex`
5. `lib/vmemo_web/live/user_confirmation_live.ex`
6. `lib/vmemo_web/live/user_confirmation_instructions_live.ex`
7. `lib/vmemo_web/live/user_reset_password_live.ex`

**其他文件**：
8. `lib/vmemo_web/components/layouts/app.html.heex`
9. `lib/vmemo_web/ash_user_auth.ex`

**测试文件**（批量修改）：
10-18. 所有测试文件中的断言文本

### 文案统一结果

现在整个应用中的认证相关文案已完全统一：
- ✅ **Login** - 统一使用，替代 Sign in
- ✅ **Register** - 统一使用，替代 Sign up / Create account
- ✅ **Logout** - 统一使用，替代 Sign out
- ✅ **Logged out** - 统一使用，替代 Signed out

### 用户体验改进

文案更加简洁明了：
- "Login to your account" - 更直接
- "Register your account" - 更清晰
- "Logout" - 更简短
- 与路由命名一致（/login, /register, /logout）

# Admin Login 实现计划

## 问题分析

### 当前状态
- 项目已有用户认证系统（基于 Ash Authentication）
- `/admin` 路由已存在，使用 AshAdmin，但需要用户认证
- 当前管理员权限检查基于邮箱 `admin@vmemo.app`
- 需要实现独立的 admin token 认证系统

### 需求定义
1. **简单性**: admin login 不需要复杂的用户系统，只需要 token 验证
2. **环境配置**:
   - dev/test: token = "admin"
   - prod: 从环境变量读取
3. **权限验证**: 独立的 admin 认证，不依赖现有用户系统
4. **用户体验**: 简单的 token input + 登录按钮

## 解决方案对比

### 方案 1: 独立 Admin Session 系统
**优点**:
- 完全独立于现有用户系统
- 简单直接，符合需求
- 易于维护和调试

**缺点**:
- 需要额外的 session 管理
- 与现有认证系统分离

### 方案 2: 扩展现有认证系统
**优点**:
- 复用现有基础设施
- 统一的认证管理

**缺点**:
- 增加复杂性
- 需要修改现有用户模型
- 不符合"简单"需求

### 方案 3: Plug.BasicAuth
**优点**:
- Phoenix 内置支持
- 极简实现

**缺点**:
- 每次请求都需要输入密码
- 用户体验不佳
- 不符合 token 需求

## 技术选择

**选择方案 1: 独立 Admin Session 系统**

理由：
- 符合"简单"需求
- 独立性强，不影响现有系统
- 易于实现和维护
- 支持 token 认证方式

## 架构设计

### 1. 配置层
```elixir
# config/dev.exs, config/test.exs
config :vmemo, admin_token: "admin"

# config/runtime.exs (prod)
config :vmemo, admin_token: System.get_env("ADMIN_TOKEN")
```

### 2. 认证层
- 创建 `AdminAuth` 模块
- 实现 admin session 管理
- 提供 `require_admin` plug
- 提供 `on_mount` 回调用于 LiveView

### 3. 路由层
```elixir
scope "/admin" do
  pipe_through [:browser]

  # Admin login page
  live "/login", AdminLoginLive, :new
  post "/login", AdminSessionController, :create

  # Protected admin routes
  pipe_through [:require_admin]
  ash_admin "/"
end
```

### 4. 控制器层
- `AdminSessionController`: 处理登录/登出
- `AdminLoginLive`: 登录页面 LiveView

### 5. 数据流
1. 用户访问 `/admin` → 重定向到 `/admin/login`
2. 用户输入 token → 提交到 `AdminSessionController`
3. 验证 token → 创建 admin session
4. 重定向到 `/admin` (AshAdmin)

## 实现步骤

### 步骤 1: 配置管理
- [ ] 在 `config/dev.exs` 添加 admin_token 配置
- [ ] 在 `config/test.exs` 添加 admin_token 配置
- [ ] 在 `config/runtime.exs` 添加生产环境配置

### 步骤 2: AdminAuth 模块
- [ ] 创建 `lib/vmemo_web/admin_auth.ex`
- [ ] 实现 `require_admin` plug
- [ ] 实现 `on_mount` 回调
- [ ] 实现 session 管理函数

### 步骤 3: AdminSessionController
- [ ] 创建 `lib/vmemo_web/controllers/admin_session_controller.ex`
- [ ] 实现 `create/2` 和 `delete/2` 函数
- [ ] 处理 token 验证逻辑

### 步骤 4: AdminLoginLive
- [ ] 创建 `lib/vmemo_web/live/admin_login_live.ex`
- [ ] 创建 `lib/vmemo_web/live/admin_login_live.html.heex`
- [ ] 实现简单的 token input 表单

### 步骤 5: 路由配置
- [ ] 修改 `lib/vmemo_web/router.ex`
- [ ] 添加 admin 登录路由
- [ ] 配置 admin 保护路由

### 步骤 6: 测试
- [ ] 创建 `test/vmemo_web/admin_auth_test.exs`
- [ ] 创建 `test/vmemo_web/controllers/admin_session_controller_test.exs`
- [ ] 创建 `test/vmemo_web/live/admin_login_live_test.exs`

## 风险评估

### 技术风险
1. **Session 冲突**: admin session 与用户 session 可能冲突
   - **缓解**: 使用不同的 session key (`admin_token` vs `user_token`)

2. **安全风险**: token 在客户端存储
   - **缓解**: 使用 HTTP-only cookies，定期轮换 token

3. **配置错误**: 生产环境 token 配置错误
   - **缓解**: 启动时验证配置，提供清晰的错误信息

### 维护风险
1. **代码重复**: 与现有认证系统有重复逻辑
   - **缓解**: 提取公共函数到共享模块

2. **测试覆盖**: 新系统需要充分测试
   - **缓解**: 创建完整的测试套件

## 安全考虑

1. **Token 安全**:
   - 生产环境使用强随机 token
   - 定期轮换 token
   - 记录登录尝试

2. **Session 安全**:
   - 使用 HTTP-only cookies
   - 设置合理的过期时间
   - CSRF 保护

3. **访问控制**:
   - 限制 admin 功能访问
   - 记录敏感操作

## 后续扩展

1. **多管理员支持**: 支持多个 admin token
2. **权限细分**: 不同 admin 不同权限
3. **审计日志**: 记录 admin 操作
4. **2FA 支持**: 二次验证

## 总结

选择独立 Admin Session 系统是最符合需求的方案，它简单、独立、易于维护，同时提供了良好的安全性和用户体验。实现过程分为 6 个步骤，每个步骤都有明确的交付物和验收标准。

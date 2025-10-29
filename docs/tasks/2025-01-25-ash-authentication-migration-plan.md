# Ash Authentication 迁移计划和验收标准

## 问题分析

### 当前状态
- 项目使用传统的 Phoenix 认证系统 (`phx_gen_auth`)
- 基于 Ecto Schema 的用户模型 (`Vmemo.Account.User`)
- 手动实现的 session 管理和 token 验证
- 独立的 Admin 认证系统 (`VmemoWeb.AdminAuth`)
- 已有 API Token 系统 (`Vmemo.Account.ApiToken`)

### 当前认证架构问题
1. **代码重复**: UserAuth 和 AdminAuth 有相似的认证逻辑
2. **维护复杂**: 手动管理 session、token 和密码哈希
3. **功能分散**: 认证逻辑分散在多个模块中
4. **扩展性差**: 添加新的认证方式需要大量手动代码
5. **测试困难**: 认证逻辑与业务逻辑耦合

### 需求定义
1. **统一认证**: 使用 Ash Authentication 统一管理所有认证需求
2. **简化维护**: 减少手动认证代码，提高可维护性
3. **功能增强**: 支持更多认证方式（OAuth、API Token 等）
4. **向后兼容**: 确保现有用户数据不丢失
5. **性能优化**: 利用 Ash 的优化特性提升性能

## 方案对比

### 方案 1: 完全迁移到 Ash Authentication
**优点**:
- 统一的认证管理
- 内置多种认证策略
- 更好的测试支持
- 与 Ash 生态系统深度集成
- 自动化的 session 管理

**缺点**:
- 需要重构现有代码
- 学习成本较高
- 迁移风险

### 方案 2: 保持现有系统，渐进式改进
**优点**:
- 风险较低
- 现有功能不受影响

**缺点**:
- 无法解决根本问题
- 技术债务持续积累
- 错过 Ash 生态系统的优势

### 方案 3: 混合方案
**优点**:
- 平衡风险和收益
- 可以逐步迁移

**缺点**:
- 系统复杂度增加
- 维护两套认证系统

## 技术选择

**选择方案 1: 完全迁移到 Ash Authentication**

理由：
- 项目已经使用 Ash 框架
- Ash Authentication 提供完整的认证解决方案
- 长期维护成本更低
- 更好的扩展性和测试支持

## 架构设计

### 1. Ash Authentication 配置

```elixir
# lib/vmemo/account/user.ex
defmodule Vmemo.Account.User do
  use Ash.Resource,
    domain: Vmemo.AccountDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshAuthentication,
      AshAuthentication.AddOn.Confirmation
    ]

  authentication do
    api Vmemo.AccountDomain

    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? true
        confirmation_required? true
      end

      add_on :confirmation do
        monitor_fields [:email]
        token_lifetime 7 * 24 * 60 * 60
      end
    end

    tokens do
      enabled true
      token_lifetime 60 * 24 * 60 * 60
      signing_secret Application.compile_env(:vmemo, :secret_key_base)
    end
  end

  postgres do
    table "account_users"
    repo Vmemo.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :confirmed_at, :utc_datetime, public?: true
    attribute :display_name, :string, public?: true
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    has_many :api_tokens, Vmemo.Account.ApiToken
  end

  actions do
    defaults [:read, :destroy, create: :register, update: :update]

    create :register do
      accept [:email, :password, :display_name]
      change hash_password/1
      change generate_confirm_token/1
    end

    update :update do
      accept [:email, :display_name]
    end

    update :change_password do
      accept [:password]
      change hash_password/1
    end
  end

  code_interface do
    define :get_by_email, action: :read, get_by: [:email]
    define :register_with_password, action: :register
    define :sign_in_with_password, action: :sign_in_with_password
  end
end
```

### 2. 认证策略配置

```elixir
# lib/vmemo/account_domain.ex
defmodule Vmemo.AccountDomain do
  use Ash.Domain,
    extensions: [
      AshAuthentication.Domain
    ]

  authentication do
    api Vmemo.AccountDomain
  end

  resources do
    resource Vmemo.Account.User
    resource Vmemo.Account.ApiToken
  end
end
```

### 3. Phoenix 集成

```elixir
# lib/vmemo_web/plugs/ash_authentication.ex
defmodule VmemoWeb.Plugs.AshAuthentication do
  use AshAuthentication.Phoenix.Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> AshAuthentication.Phoenix.Plug.load_from_session()
    |> AshAuthentication.Phoenix.Plug.load_from_bearer()
  end
end
```

### 4. LiveView 集成

```elixir
# lib/vmemo_web/live/user_session_live.ex
defmodule VmemoWeb.UserSessionLive do
  use VmemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("sign_in", %{"email" => email, "password" => password}, socket) do
    case AshAuthentication.sign_in_with_password(email, password) do
      {:ok, user, token} ->
        socket =
          socket
          |> put_flash(:info, "Signed in successfully")
          |> redirect(to: ~p"/home")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Invalid email or password")

        {:noreply, socket}
    end
  end
end
```

## 迁移步骤和 Todo List

### 阶段 1: 准备和依赖安装 (1-2天)
- [ ] **添加 Ash Authentication 依赖到 mix.exs**
  ```elixir
  {:ash_authentication, "~> 3.0"},
  {:ash_authentication_phoenix, "~> 1.0"}
  ```
- [ ] **创建用户数据备份脚本**
- [ ] **制定回滚计划文档**

### 阶段 2: 数据模型迁移 (3-5天)
- [ ] **创建新的 Ash User 资源定义**
- [ ] **配置 Ash Authentication 策略**
- [ ] **创建数据库迁移脚本**
  ```elixir
  # priv/repo/migrations/xxx_migrate_to_ash_auth.exs
  defmodule Vmemo.Repo.Migrations.MigrateToAshAuth do
    use Ecto.Migration

    def up do
      # 迁移现有用户数据到新的表结构
      execute """
        INSERT INTO ash_users (id, email, hashed_password, confirmed_at, display_name, inserted_at, updated_at)
        SELECT id, email, hashed_password, confirmed_at, display_name, inserted_at, updated_at
        FROM account_users
      """
    end

    def down do
      # 回滚逻辑
    end
  end
  ```
- [ ] **更新 AccountDomain 配置**

### 阶段 3: 认证逻辑迁移 (5-7天)
- [ ] **创建 Ash Authentication Phoenix 集成**
- [ ] **更新路由和管道配置**
- [ ] **修改 LiveView 认证回调**
- [ ] **集成 Admin 认证到 Ash Authentication**
- [ ] **移除旧的 UserAuth 和 AdminAuth 模块**

### 阶段 4: 测试和验证 (3-5天)
- [ ] **编写认证功能单元测试**
- [ ] **编写集成测试验证完整认证流程**
- [ ] **验证 API Token 功能正常工作**
- [ ] **执行用户验收测试**

### 阶段 5: 部署和监控 (2-3天)
- [ ] **生产环境部署和数据迁移**
- [ ] **设置性能监控和错误日志**
- [ ] **性能优化和配置调优**

**总计**: 14-22 天

## 风险评估

### 高风险
1. **数据丢失**: 迁移过程中可能丢失用户数据
   - **缓解措施**: 完整备份，分阶段迁移，回滚计划

2. **功能中断**: 认证系统故障导致用户无法登录
   - **缓解措施**: 蓝绿部署，快速回滚机制

### 中风险
1. **性能问题**: 新系统性能不如预期
   - **缓解措施**: 性能测试，监控指标

2. **兼容性问题**: 与现有代码不兼容
   - **缓解措施**: 充分测试，渐进式迁移

### 低风险
1. **学习成本**: 团队需要学习 Ash Authentication
   - **缓解措施**: 培训计划，文档支持

## 验收标准

### 功能完整性验收

#### 1. 用户注册功能
- [ ] 用户可以通过邮箱和密码注册新账户
- [ ] 注册时发送确认邮件
- [ ] 邮箱格式验证正常工作
- [ ] 密码强度验证符合要求（最少12位）
- [ ] 重复邮箱注册被正确拒绝
- [ ] 注册成功后用户状态正确设置

#### 2. 用户登录功能
- [ ] 用户可以使用邮箱和密码登录
- [ ] 错误的邮箱或密码被正确拒绝
- [ ] 登录成功后创建有效的 session
- [ ] Remember me 功能正常工作
- [ ] 登录后重定向到正确的页面
- [ ] 未确认邮箱的用户登录被正确限制

#### 3. 密码管理功能
- [ ] 用户可以修改密码
- [ ] 修改密码需要验证当前密码
- [ ] 忘记密码功能正常工作
- [ ] 密码重置邮件发送正常
- [ ] 密码重置链接有效且有时效性
- [ ] 密码重置后旧 session 失效

#### 4. 邮箱确认功能
- [ ] 新用户注册后收到确认邮件
- [ ] 确认链接有效且有时效性
- [ ] 点击确认链接后用户状态更新
- [ ] 未确认用户无法访问受保护页面
- [ ] 重新发送确认邮件功能正常

#### 5. 会话管理功能
- [ ] 用户登录后 session 正确创建
- [ ] 用户登出后 session 正确清除
- [ ] Session 超时机制正常工作
- [ ] 多设备登录管理正常
- [ ] 强制登出功能正常

#### 6. Admin 认证功能
- [ ] Admin 可以使用 token 登录
- [ ] Admin 登录后可以访问 AshAdmin
- [ ] Admin 登出功能正常
- [ ] 非 admin 用户无法访问 admin 页面
- [ ] Admin session 独立于用户 session

#### 7. API Token 功能
- [ ] 用户可以创建 API Token
- [ ] API Token 可以用于 API 认证
- [ ] API Token 可以撤销
- [ ] API Token 列表显示正常
- [ ] API Token 权限控制正常

### 数据完整性验收

#### 1. 用户数据迁移
- [ ] 所有现有用户数据成功迁移
- [ ] 用户邮箱地址保持不变
- [ ] 用户密码哈希正确迁移
- [ ] 用户确认状态正确迁移
- [ ] 用户创建时间保持不变
- [ ] 用户显示名称正确迁移

#### 2. API Token 数据迁移
- [ ] 所有现有 API Token 成功迁移
- [ ] Token 与用户的关联关系正确
- [ ] Token 权限设置保持不变
- [ ] Token 创建时间保持不变

#### 3. 数据一致性验证
- [ ] 迁移后用户总数与迁移前一致
- [ ] 迁移后 API Token 总数与迁移前一致
- [ ] 所有外键关系正确维护
- [ ] 数据库约束正确设置

### 性能验收

#### 1. 响应时间
- [ ] 用户登录响应时间 ≤ 500ms
- [ ] 用户注册响应时间 ≤ 800ms
- [ ] 密码重置响应时间 ≤ 600ms
- [ ] API Token 验证响应时间 ≤ 200ms
- [ ] Admin 登录响应时间 ≤ 300ms

#### 2. 并发性能
- [ ] 支持 100 并发用户登录
- [ ] 支持 50 并发 API Token 验证
- [ ] 数据库连接池使用正常
- [ ] 内存使用在合理范围内

#### 3. 资源使用
- [ ] CPU 使用率不超过现有系统的 120%
- [ ] 内存使用率不超过现有系统的 110%
- [ ] 数据库查询次数合理
- [ ] 网络请求次数优化

### 安全性验收

#### 1. 密码安全
- [ ] 密码使用 bcrypt 哈希存储
- [ ] 密码不在日志中泄露
- [ ] 密码重置 token 有时效性
- [ ] 密码重置 token 使用后失效

#### 2. Session 安全
- [ ] Session token 随机生成
- [ ] Session token 有合理长度
- [ ] Session 超时机制正常
- [ ] Session 在登出后正确清除

#### 3. API Token 安全
- [ ] API Token 随机生成
- [ ] API Token 有合理长度
- [ ] API Token 可以撤销
- [ ] API Token 权限控制正确

#### 4. 输入验证
- [ ] 邮箱格式验证正确
- [ ] 密码强度验证正确
- [ ] SQL 注入防护正常
- [ ] XSS 防护正常

### 用户体验验收

#### 1. 登录流程
- [ ] 登录页面加载正常
- [ ] 登录表单验证提示清晰
- [ ] 登录成功后重定向正确
- [ ] 登录失败提示友好

#### 2. 注册流程
- [ ] 注册页面加载正常
- [ ] 注册表单验证提示清晰
- [ ] 注册成功后提示友好
- [ ] 确认邮件发送提示清晰

#### 3. 密码管理
- [ ] 密码修改页面正常
- [ ] 密码重置页面正常
- [ ] 密码重置邮件内容清晰
- [ ] 密码重置成功提示友好

#### 4. Admin 界面
- [ ] Admin 登录页面正常
- [ ] Admin 登录表单验证正常
- [ ] Admin 登录成功后访问 AshAdmin 正常
- [ ] Admin 登出功能正常

### 兼容性验收

#### 1. 浏览器兼容性
- [ ] Chrome 最新版本正常
- [ ] Firefox 最新版本正常
- [ ] Safari 最新版本正常
- [ ] Edge 最新版本正常

#### 2. 移动端兼容性
- [ ] iOS Safari 正常
- [ ] Android Chrome 正常
- [ ] 响应式设计正常
- [ ] 触摸操作正常

#### 3. API 兼容性
- [ ] 现有 API 调用正常
- [ ] API Token 认证正常
- [ ] API 响应格式不变
- [ ] API 错误处理正常

### 监控和日志验收

#### 1. 错误监控
- [ ] 认证错误正确记录
- [ ] 系统错误正确记录
- [ ] 错误级别分类正确
- [ ] 错误通知机制正常

#### 2. 性能监控
- [ ] 响应时间监控正常
- [ ] 并发用户数监控正常
- [ ] 数据库性能监控正常
- [ ] 内存使用监控正常

#### 3. 安全监控
- [ ] 登录失败次数监控
- [ ] 异常登录行为监控
- [ ] API Token 使用监控
- [ ] 安全事件告警正常

### 回滚验收

#### 1. 回滚准备
- [ ] 回滚脚本准备完成
- [ ] 数据备份验证正常
- [ ] 回滚流程文档完整
- [ ] 回滚测试通过

#### 2. 回滚执行
- [ ] 回滚脚本可以正常执行
- [ ] 回滚后系统功能正常
- [ ] 回滚后数据完整性正常
- [ ] 回滚后性能正常

### 文档验收

#### 1. 技术文档
- [ ] API 文档更新完成
- [ ] 部署文档更新完成
- [ ] 配置文档更新完成
- [ ] 故障排除文档完成

#### 2. 用户文档
- [ ] 用户使用指南更新
- [ ] Admin 使用指南更新
- [ ] 常见问题解答更新
- [ ] 变更通知发布

## 验收通过标准

### 必要条件
- 所有功能完整性验收项目通过
- 所有数据完整性验收项目通过
- 所有安全性验收项目通过
- 性能指标达到要求
- 回滚测试通过

### 可选条件
- 用户体验验收项目通过
- 兼容性验收项目通过
- 监控和日志验收项目通过
- 文档验收项目通过

## 验收流程和时间计划

1. **开发环境验收**: 在开发环境完成所有验收项目 (2-3 天)
2. **测试环境验收**: 在测试环境完成所有验收项目 (1-2 天)
3. **预生产环境验收**: 在预生产环境完成所有验收项目 (1-2 天)
4. **生产环境验收**: 在生产环境完成关键验收项目 (1 天)
5. **用户验收测试**: 邀请真实用户进行验收测试 (2-3 天)

**验收总计**: 7-11 天

## 成功标准

1. **功能完整性**: 所有现有认证功能正常工作
2. **性能指标**: 认证响应时间不超过现有系统的 120%
3. **数据完整性**: 100% 用户数据成功迁移
4. **用户体验**: 用户登录流程无感知变化
5. **代码质量**: 认证相关代码减少 50% 以上

## 后续优化

1. **OAuth 集成**: 支持 Google、GitHub 等第三方登录
2. **多因素认证**: 添加 2FA 支持
3. **权限管理**: 集成 Ash Authorization
4. **审计日志**: 添加认证事件日志
5. **性能优化**: 缓存和查询优化

## 结论

迁移到 Ash Authentication 是一个值得投入的项目，虽然有一定的迁移风险，但长期收益明显：

- **维护成本降低**: 统一的认证管理
- **功能增强**: 支持更多认证方式
- **代码质量**: 减少重复代码，提高可维护性
- **生态系统**: 与 Ash 框架深度集成

建议按照分阶段的方式进行迁移，确保每个阶段都有充分的测试和回滚计划。

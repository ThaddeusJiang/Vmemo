# API Token 架构重构总结

## 架构设计原则

根据您的要求，我们保持了 **Account** 和 **API Token** 的独立性：

- **Account 模块**：负责用户注册、登录、密码管理等核心用户功能
- **ApiTokenService 模块**：负责 API Token 的创建、管理、验证等 Public API 功能
- **AshRepo**：专门用于 API Token 相关的数据操作

## 新的模块结构

### 1. Account 模块（保持不变）
```elixir
# lib/vmemo/account.ex
defmodule Vmemo.Account do
  # 用户注册、登录、密码管理等功能
  # 使用传统的 Ecto + Repo
end
```

### 2. API Token Ash 资源
```elixir
# lib/vmemo/account/api_token.ex
defmodule Vmemo.Account.ApiToken do
  use Ash.Resource,
    domain: Vmemo.Account,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "api_tokens"
    repo Vmemo.AshRepo  # 使用 AshRepo
  end

  # Ash 资源定义...
end
```

### 3. API Token 使用记录 Ash 资源
```elixir
# lib/vmemo/account/api_token_usage_log.ex
defmodule Vmemo.Account.ApiTokenUsageLog do
  use Ash.Resource,
    domain: Vmemo.Account,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "api_token_usage_logs"
    repo Vmemo.AshRepo  # 使用 AshRepo
  end

  # Ash 资源定义...
end
```

### 4. 独立的 API Token 服务
```elixir
# lib/vmemo/api_token_service.ex
defmodule Vmemo.ApiTokenService do
  @moduledoc """
  API Token 服务模块，使用 AshRepo 处理 API Token 相关功能
  """

  alias Vmemo.Account.{ApiToken, ApiTokenUsageLog}

  # 所有 API Token 相关的业务逻辑
  def list_user_api_tokens(user), do: # ...
  def create_api_token(user, attrs), do: # ...
  def verify_api_token(token), do: # ...
  # ... 其他函数
end
```

### 5. Account Domain（Ash）
```elixir
# lib/vmemo/account.ex (Domain)
defmodule Vmemo.Account do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Vmemo.Account.User
    resource Vmemo.Account.ApiToken
    resource Vmemo.Account.ApiTokenUsageLog
  end
end
```

## 数据流架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Account       │    │  ApiTokenService │    │   AshRepo       │
│   (用户管理)     │    │  (Token 服务)    │    │   (数据层)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Ecto + Repo   │    │   Ash Resources   │    │   PostgreSQL    │
│   (用户数据)     │    │   (Token 数据)    │    │   (数据库)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 关键优势

### 1. 职责分离
- **Account**：专注于用户身份验证和管理
- **ApiTokenService**：专注于 API 访问控制
- **AshRepo**：专注于 API Token 数据操作

### 2. 技术栈选择
- **用户管理**：继续使用成熟的 Ecto + Repo
- **API Token**：使用现代化的 Ash + AshRepo
- **数据库**：统一使用 PostgreSQL

### 3. 维护性
- 模块边界清晰，易于理解和维护
- 可以独立测试和部署
- 符合单一职责原则

## 使用示例

### 用户注册（Account 模块）
```elixir
# 用户注册仍然使用 Account 模块
Vmemo.Account.register_user(%{email: "user@example.com", password: "password"})
```

### API Token 管理（ApiTokenService）
```elixir
# API Token 操作使用 ApiTokenService
Vmemo.ApiTokenService.create_api_token(user, %{name: "My API Token"})
Vmemo.ApiTokenService.verify_api_token("vmemo_abc123...")
```

### LiveView 集成
```elixir
# ApiTokenLive 使用 ApiTokenService
alias Vmemo.ApiTokenService

def mount(_params, _session, socket) do
  user = socket.assigns.current_user
  api_tokens = ApiTokenService.list_user_api_tokens(user)
  # ...
end
```

## 总结

这种架构设计完美实现了您的要求：

✅ **Account 模块独立**：保持原有的用户管理功能不变
✅ **API Token 使用 AshRepo**：现代化的数据操作方式
✅ **职责清晰分离**：用户管理 vs API Token 管理
✅ **技术栈合理**：传统 Ecto + 现代 Ash 的混合使用
✅ **易于维护**：模块边界清晰，便于后续开发

这种设计既保持了系统的稳定性，又引入了现代化的 Ash 框架来处理 API Token 相关的复杂业务逻辑。

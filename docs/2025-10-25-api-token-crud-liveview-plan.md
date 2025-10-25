# API Token CRUD LiveView UI 页面开发计划

## 问题分析

### 当前状态
- 项目已有完整的用户认证系统（基于 session token）
- 已有用户设置页面 (`UserSettingsLive`) 作为参考
- 使用 Ash Framework 进行数据管理
- 已有完整的 UI 组件库（CoreComponents）
- 使用 Tailwind CSS + DaisyUI 进行样式设计
- 已有 Modal、Table、Form 等核心组件

### 需求定义
1. **API Token 管理界面**: 为用户提供创建、查看、编辑、删除 API Token 的功能
2. **安全性**: Token 生成、显示、过期管理
3. **用户体验**: 直观的界面，清晰的操作流程
4. **集成性**: 与现有的用户设置页面集成

## 方案对比

### 方案 1: 扩展现有 UserSettingsLive
**优点**:
- 复用现有的用户设置页面结构
- 保持界面一致性
- 减少路由复杂度

**缺点**:
- 页面可能过于复杂
- API Token 功能可能被埋没

### 方案 2: 创建独立的 ApiTokenLive 页面
**优点**:
- 功能独立，易于维护
- 可以专门优化 API Token 管理体验
- 便于未来扩展

**缺点**:
- 需要额外的路由配置
- 与用户设置页面分离

### 方案 3: 使用 Modal 弹窗形式
**优点**:
- 不离开当前页面
- 快速操作
- 节省页面空间

**缺点**:
- 复杂操作在 Modal 中体验不佳
- 移动端适配困难

## 技术选型

**✅ 已选择方案 2: 创建独立的 ApiTokenLive 页面**

### 选择理由
- **功能重要性**: API Token 管理是核心功能，值得独立页面
- **用户体验**: 操作空间充足，界面清晰，交互流畅
- **可扩展性**: 便于未来添加更多 API 相关功能（如使用统计、权限管理等）
- **维护性**: 符合单一职责原则，代码结构清晰
- **一致性**: 与现有页面结构保持一致（如 UserSettingsLive）

### 方案对比结果
| 方案 | 优点 | 缺点 | 评分 |
|------|------|------|------|
| 方案1: 扩展UserSettingsLive | 复用现有结构 | 页面复杂，功能埋没 | ❌ |
| **方案2: 独立ApiTokenLive** | **功能独立，体验好** | **需要额外路由** | **✅ 推荐** |
| 方案3: Modal弹窗 | 不离开当前页面 | 复杂操作体验差 | ❌ |

## 架构设计

### 1. 路由设计
**独立页面路由配置**:
```elixir
scope "/", VmemoWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{VmemoWeb.UserAuth, :ensure_authenticated}] do
    # ... 现有路由 ...
    live "/users/settings", UserSettingsLive, :edit
    live "/users/tokens", ApiTokenLive, :index  # 新增独立页面
  end
end
```

**页面导航集成**:
- 在用户设置页面添加 "API Tokens" 链接
- 在主导航中添加 API 管理入口
- 支持面包屑导航

### 2. 数据模型设计

#### 2.1 ApiToken 模型（安全存储）
```elixir
defmodule Vmemo.Account.ApiToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_tokens" do
    field :token_hash, :string  # 只存储 token 的 hash，不存储原始 token
    field :name, :string
    field :description, :string
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :created_at, :utc_datetime  # 创建时间，用于 token 显示
    belongs_to :user, Vmemo.Account.User

    # 关联使用记录
    has_many :usage_logs, Vmemo.Account.ApiTokenUsageLog

    timestamps()
  end

  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:name, :description, :expires_at])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_future_date(:expires_at)
    |> unique_constraint(:token_hash)
  end

  # Token 生成和 hash 计算
  def generate_token do
    # 生成 32 字节的随机 token
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    # 添加前缀便于识别
    prefixed_token = "vmemo_" <> token
    # 计算 hash
    hash = :crypto.hash(:sha256, prefixed_token) |> Base.encode16(case: :lower)
    {prefixed_token, hash}
  end

  # 验证 token
  def verify_token(token, token_hash) do
    computed_hash = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
    computed_hash == token_hash
  end
end
```

#### 2.2 ApiTokenUsageLog 模型（软删除）
```elixir
defmodule Vmemo.Account.ApiTokenUsageLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_token_usage_logs" do
    field :action, :string  # "create", "used", "revoked", "expired"
    field :ip_address, :string
    field :user_agent, :string
    field :endpoint, :string  # API 端点，如 "/api/v1/photos"
    field :method, :string   # HTTP 方法，如 "POST"
    field :status_code, :integer  # HTTP 状态码
    field :response_time_ms, :integer  # 响应时间（毫秒）
    field :request_size_bytes, :integer  # 请求大小
    field :response_size_bytes, :integer  # 响应大小
    field :error_message, :string  # 错误信息（如果有）
    field :deleted_at, :utc_datetime  # 软删除时间戳
    belongs_to :api_token, Vmemo.Account.ApiToken
    belongs_to :user, Vmemo.Account.User

    timestamps()
  end

  def changeset(usage_log, attrs) do
    usage_log
    |> cast(attrs, [:action, :ip_address, :user_agent, :endpoint, :method,
                    :status_code, :response_time_ms, :request_size_bytes,
                    :response_size_bytes, :error_message, :api_token_id, :user_id])
    |> validate_required([:action, :api_token_id, :user_id])
    |> validate_inclusion(:action, ["create", "used", "revoked", "expired"])
    |> validate_inclusion(:method, ["GET", "POST", "PUT", "DELETE", "PATCH"])
    |> validate_number(:status_code, greater_than_or_equal_to: 100, less_than_or_equal_to: 599)
    |> validate_number(:response_time_ms, greater_than_or_equal_to: 0)
    |> validate_number(:request_size_bytes, greater_than_or_equal_to: 0)
    |> validate_number(:response_size_bytes, greater_than_or_equal_to: 0)
  end

  # 软删除 changeset
  def soft_delete_changeset(usage_log) do
    change(usage_log, deleted_at: DateTime.utc_now())
  end

  # 查询时排除软删除的记录
  def active_logs_query do
    from log in __MODULE__, where: is_nil(log.deleted_at)
  end
end
```

### 3. 页面结构设计
**独立 ApiTokenLive 页面布局**:
```
ApiTokenLive (/users/tokens)
├── Layouts.app (复用现有布局)
├── 页面头部
│   ├── 标题: "API Token 管理"
│   ├── 描述: "管理您的 API 访问令牌"
│   └── 创建按钮: "创建新 Token"
├── 主要内容区域
│   ├── Token 统计卡片
│   │   ├── 总数统计
│   │   ├── 活跃 Token 数
│   │   ├── 过期 Token 数
│   │   └── 今日使用次数
│   ├── Token 列表表格
│   │   ├── Token 名称 + 状态标签
│   │   ├── Token 预览 (创建时间 + 前4位hash)
│   │   ├── 创建时间
│   │   ├── 过期时间
│   │   ├── 最后使用时间
│   │   ├── 使用次数
│   │   └── 操作按钮 (编辑/删除/复制/查看记录)
│   └── Token 使用记录区域 (可展开)
│       ├── 使用记录表格
│       │   ├── 时间戳
│       │   ├── 操作类型 (create/used/revoked)
│       │   ├── API 端点
│       │   ├── HTTP 方法
│       │   ├── 状态码
│       │   ├── 响应时间
│       │   ├── IP 地址
│       │   └── 用户代理
│       ├── 分页控制
│       └── 筛选选项 (按时间、操作类型、状态码)
├── 创建/编辑 Modal
│   ├── Token 名称输入
│   ├── 描述输入
│   ├── 过期时间选择
│   └── 确认/取消按钮
├── 删除确认 Modal
│   ├── 警告信息
│   ├── Token 详情
│   └── 确认/取消按钮
└── 使用记录详情 Modal
    ├── 记录详情表格
    ├── 请求/响应信息
    ├── 错误信息 (如果有)
    └── 关闭按钮
```

**页面特点**:
- 独立页面，不依赖其他页面
- 完整的 CRUD 操作界面
- **新增使用记录功能**：详细记录 Token 的创建和使用历史
- **安全存储**：Token 只显示一次，之后只显示 hash 预览
- **软删除**：使用记录支持软删除，数据保留但用户不可见
- 响应式设计，支持移动端
- 清晰的信息层次和操作流程
- 支持使用记录的筛选和分页

### 4. 数据流设计
```
用户操作
  ↓
LiveView handle_event
  ↓
Account 模块函数
  ↓
Ecto 数据库操作
  ↓
更新 LiveView assigns
  ↓
重新渲染页面
```

## 风险评估

### 技术风险
1. **Token 安全性**: Token 生成和存储的安全性
2. **性能问题**: 大量 Token 的列表渲染性能
3. **并发操作**: 同时创建多个 Token 的并发处理

### 安全风险
1. **Token 泄露**: Token 在页面显示时的安全性
2. **权限控制**: 确保用户只能管理自己的 Token
3. **Token 过期**: 过期 Token 的自动清理

### 用户体验风险
1. **操作复杂性**: Token 管理操作过于复杂
2. **错误处理**: 操作失败时的错误提示
3. **移动端适配**: 在小屏幕设备上的使用体验

## 实现计划

### 阶段 1: 数据模型和基础功能 (1-2 天)
**目标**: 建立 ApiTokenLive 页面的基础架构
- [ ] 创建 ApiToken schema 和 migration
- [ ] **创建 ApiTokenUsageLog schema 和 migration**
- [ ] 实现 Account 模块的 CRUD 函数
- [ ] **实现使用记录记录函数**
- [ ] 创建独立的 `ApiTokenLive` 页面文件
- [ ] 配置路由 `/users/api-tokens`
- [ ] 实现基础的 Token 列表显示（使用 Table 组件）
- [ ] 添加页面头部和创建按钮

### 阶段 2: CRUD 操作实现 (2-3 天)
**目标**: 完成所有 Token 管理功能
- [ ] 实现创建 Token 功能（Modal 表单）
- [ ] **记录 Token 创建日志**
- [ ] 实现编辑 Token 功能（Modal 表单）
- [ ] 实现删除 Token 功能（确认 Modal）
- [ ] **记录 Token 删除日志**
- [ ] 实现 Token 复制功能（一键复制到剪贴板）
- [ ] 添加 Token 状态切换功能（启用/禁用）
- [ ] 实现表单验证和错误处理

### 阶段 3: 使用记录功能实现 (2-3 天)
**目标**: 实现完整的使用记录功能
- [ ] **实现使用记录列表显示**
- [ ] **添加使用记录筛选功能**（按时间、操作类型、状态码）
- [ ] **实现使用记录分页功能**
- [ ] **添加使用记录详情 Modal**
- [ ] **实现使用统计卡片**（总数、活跃、过期、今日使用）
- [ ] **添加使用记录导出功能**（CSV/JSON）
- [ ] **实现使用记录搜索功能**

### 阶段 4: 用户体验优化 (1-2 天)
**目标**: 提升用户交互体验
- [ ] 添加加载状态和错误处理
- [ ] 实现 Token 状态显示（活跃/过期/禁用）
- [ ] **优化使用记录显示**（时间格式化、状态码颜色）
- [ ] 优化移动端体验（响应式设计）
- [ ] 添加操作成功/失败的 Flash 消息
- [ ] 实现 Token 过期提醒
- [ ] **添加使用记录实时更新**（WebSocket）

### 阶段 5: 测试和优化 (1-2 天)
**目标**: 确保功能稳定和安全
- [ ] 编写 Account 模块单元测试
- [ ] **编写使用记录功能单元测试**
- [ ] 编写 ApiTokenLive LiveView 测试
- [ ] **编写使用记录 LiveView 测试**
- [ ] 性能测试和优化（大量 Token 和记录的列表渲染）
- [ ] 安全测试（权限验证、Token 泄露防护）
- [ ] 集成测试（与 Upload API 的配合使用）
- [ ] **使用记录性能测试**（大量日志的处理）

## 技术细节

### Token 生成策略（安全存储）
```elixir
def generate_api_token do
  # 生成 32 字节的随机 token
  token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  # 添加前缀便于识别
  prefixed_token = "vmemo_" <> token
  # 计算 hash
  hash = :crypto.hash(:sha256, prefixed_token) |> Base.encode16(case: :lower)
  {prefixed_token, hash}
end

# Token 验证（通过 hash 验证）
def verify_api_token(token) do
  # 从数据库查找匹配的 hash
  hash = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

  case Repo.get_by(ApiToken, token_hash: hash, is_active: true) do
    nil -> {:error, "Invalid token"}
    api_token ->
      # 检查是否过期
      if DateTime.compare(DateTime.utc_now(), api_token.expires_at) == :gt do
        {:error, "Token expired"}
      else
        {:ok, api_token}
      end
  end
end
```

### Token 显示策略（安全显示）
```elixir
def display_token_preview(api_token) do
  # 只显示创建时间和 hash 的前4位
  created_date = Calendar.strftime(api_token.created_at, "%Y-%m-%d")
  hash_preview = String.slice(api_token.token_hash, 0, 4)
  "#{created_date}_#{hash_preview}..."
end

# 创建时显示完整 token（仅一次）
def show_token_once(token) do
  # 在创建成功后显示完整 token，之后不再显示
  token
end
```

### 软删除实现
```elixir
# 软删除使用记录
def soft_delete_usage_log(log_id, user_id) do
  case Repo.get_by(ApiTokenUsageLog, id: log_id, user_id: user_id) do
    nil -> {:error, "Log not found"}
    log ->
      log
      |> ApiTokenUsageLog.soft_delete_changeset()
      |> Repo.update()
  end
end

# 查询时排除软删除的记录
def list_user_usage_logs(user_id, opts \\ []) do
  ApiTokenUsageLog
  |> ApiTokenUsageLog.active_logs_query()
  |> where([log], log.user_id == ^user_id)
  |> order_by([log], desc: log.inserted_at)
  |> Repo.paginate(opts)
end
```

### 过期时间处理
```elixir
def default_expires_at do
  # 默认 1 年后过期
  DateTime.utc_now()
  |> DateTime.add(365 * 24 * 60 * 60, :second)
end
```

### 权限验证
```elixir
def can_manage_token?(user, api_token) do
  user.id == api_token.user_id
end
```

### 使用记录记录策略
```elixir
def log_token_usage(api_token, action, conn, opts \\ []) do
  # 从连接中提取信息
  ip_address = get_client_ip(conn)
  user_agent = get_req_header(conn, "user-agent") |> List.first()

  # 记录使用日志
  Account.create_usage_log(%{
    api_token_id: api_token.id,
    user_id: api_token.user_id,
    action: action,
    ip_address: ip_address,
    user_agent: user_agent,
    endpoint: opts[:endpoint],
    method: opts[:method],
    status_code: opts[:status_code],
    response_time_ms: opts[:response_time_ms],
    request_size_bytes: opts[:request_size_bytes],
    response_size_bytes: opts[:response_size_bytes],
    error_message: opts[:error_message]
  })
end

defp get_client_ip(conn) do
  # 优先从 X-Forwarded-For 获取真实 IP
  case get_req_header(conn, "x-forwarded-for") do
    [ip | _] -> ip |> String.split(",") |> List.first() |> String.trim()
    [] ->
      case get_req_header(conn, "x-real-ip") do
        [ip | _] -> ip
        [] -> to_string(:inet.ntoa(conn.remote_ip))
      end
  end
end
```

### API 中间件集成
```elixir
# 在 API Controller 中添加使用记录
defmodule VmemoWeb.Api.V1.PhotoController do
  use VmemoWeb, :controller

  def create(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    # 验证 API Token
    case verify_api_token(conn) do
      {:ok, api_token} ->
        # 处理请求
        result = handle_photo_upload(params)

        # 记录使用日志
        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time

        Account.log_token_usage(api_token, "used", conn, %{
          endpoint: "/api/v1/photos",
          method: "POST",
          status_code: 200,
          response_time_ms: response_time,
          request_size_bytes: byte_size(Poison.encode!(params)),
          response_size_bytes: byte_size(Poison.encode!(result))
        })

        json(conn, result)

      {:error, reason} ->
        # 记录错误日志
        Account.log_token_usage(nil, "used", conn, %{
          endpoint: "/api/v1/photos",
          method: "POST",
          status_code: 401,
          error_message: reason
        })

        conn
        |> put_status(401)
        |> json(%{error: reason})
    end
  end
end
```

## UI 组件设计

### Token 列表表格（安全显示）
```elixir
<.table id="api-tokens" rows={@api_tokens}>
  <:col :let={token} label="名称">
    <div class="flex items-center gap-2">
      <span class="font-medium">{token.name}</span>
      <span :if={!token.is_active} class="badge badge-warning badge-sm">已禁用</span>
      <span :if={is_expired?(token)} class="badge badge-error badge-sm">已过期</span>
    </div>
  </:col>
  <:col :let={token} label="Token">
    <div class="flex items-center gap-2">
      <code class="text-sm bg-base-200 px-2 py-1 rounded">{display_token_preview(token)}</code>
      <span class="text-xs text-gray-500">仅创建时可见</span>
    </div>
  </:col>
  <:col :let={token} label="创建时间">
    {Calendar.strftime(token.inserted_at, "%Y-%m-%d %H:%M")}
  </:col>
  <:col :let={token} label="过期时间">
    {Calendar.strftime(token.expires_at, "%Y-%m-%d %H:%M")}
  </:col>
  <:col :let={token} label="最后使用">
    {if token.last_used_at, do: Calendar.strftime(token.last_used_at, "%Y-%m-%d %H:%M"), else: "从未使用"}
  </:col>
  <:col :let={token} label="使用次数">
    <span class="badge badge-info">{token.usage_count || 0}</span>
  </:col>
  <:action :let={token}>
    <.button variant="ghost" phx-click="view_usage_logs" phx-value-id={token.id}>
      <.icon name="hero-chart-bar" class="h-4 w-4" />
    </.button>
    <.button variant="ghost" phx-click="edit_token" phx-value-id={token.id}>
      <.icon name="hero-pencil" class="h-4 w-4" />
    </.button>
    <.button variant="danger" phx-click="delete_token" phx-value-id={token.id}>
      <.icon name="hero-trash" class="h-4 w-4" />
    </.button>
  </:action>
</.table>
```

### Token 创建成功显示（仅一次）
```elixir
<.modal id="token-created-modal" show={@show_token_created} on_cancel={JS.hide(to: "#token-created-modal")}>
  <:header>
    <h3 class="text-lg font-semibold text-success">Token 创建成功</h3>
  </:header>

  <div class="space-y-4">
    <div class="alert alert-warning">
      <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
      <span>请立即复制并保存此 Token，创建后将无法再次查看完整内容。</span>
    </div>

    <div class="form-control">
      <label class="label">
        <span class="label-text">您的 API Token</span>
      </label>
      <div class="flex items-center gap-2">
        <input
          type="text"
          value={@new_token}
          readonly
          class="input input-bordered flex-1 font-mono text-sm"
          id="token-input"
        />
        <.button
          variant="outline"
          phx-click="copy_token"
          phx-value-token={@new_token}
          class="btn-sm"
        >
          <.icon name="hero-clipboard" class="h-4 w-4" />
        </.button>
      </div>
    </div>

    <div class="text-sm text-gray-600">
      <p>• Token 格式: vmemo_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</p>
      <p>• 过期时间: {Calendar.strftime(@new_token_expires_at, "%Y-%m-%d %H:%M")}</p>
      <p>• 使用方式: Authorization: Bearer {String.slice(@new_token, 0, 20)}...</p>
    </div>
  </div>

  <:footer>
    <.button phx-click={JS.hide(to: "#token-created-modal")}>我已保存</.button>
  </:footer>
</.modal>
```

### 使用记录表格
```elixir
<.table id="usage-logs" rows={@usage_logs}>
  <:col :let={log} label="时间">
    <div class="text-sm">
      <div>{Calendar.strftime(log.inserted_at, "%Y-%m-%d")}</div>
      <div class="text-gray-500">{Calendar.strftime(log.inserted_at, "%H:%M:%S")}</div>
    </div>
  </:col>
  <:col :let={log} label="操作">
    <span class={[
      "badge badge-sm",
      log.action == "create" && "badge-success",
      log.action == "used" && "badge-info",
      log.action == "revoked" && "badge-warning",
      log.action == "expired" && "badge-error"
    ]}>
      {case log.action do
        "create" -> "创建"
        "used" -> "使用"
        "revoked" -> "撤销"
        "expired" -> "过期"
      end}
    </span>
  </:col>
  <:col :let={log} label="API 端点">
    <code class="text-xs bg-base-200 px-1 py-0.5 rounded">{log.endpoint}</code>
  </:col>
  <:col :let={log} label="方法">
    <span class={[
      "badge badge-sm",
      log.method == "GET" && "badge-info",
      log.method == "POST" && "badge-success",
      log.method == "PUT" && "badge-warning",
      log.method == "DELETE" && "badge-error"
    ]}>
      {log.method}
    </span>
  </:col>
  <:col :let={log} label="状态码">
    <span class={[
      "badge badge-sm",
      log.status_code >= 200 && log.status_code < 300 && "badge-success",
      log.status_code >= 300 && log.status_code < 400 && "badge-info",
      log.status_code >= 400 && log.status_code < 500 && "badge-warning",
      log.status_code >= 500 && "badge-error"
    ]}>
      {log.status_code}
    </span>
  </:col>
  <:col :let={log} label="响应时间">
    {if log.response_time_ms, do: "#{log.response_time_ms}ms", else: "-"}
  </:col>
  <:col :let={log} label="IP 地址">
    <code class="text-xs">{log.ip_address}</code>
  </:col>
  <:action :let={log}>
    <.button variant="ghost" phx-click="view_log_detail" phx-value-id={log.id}>
      <.icon name="hero-eye" class="h-4 w-4" />
    </.button>
  </:action>
</.table>
```

### 使用统计卡片
```elixir
<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
  <div class="stat bg-base-100 rounded-box shadow">
    <div class="stat-figure text-primary">
      <.icon name="hero-key" class="h-8 w-8" />
    </div>
    <div class="stat-title">总 Token 数</div>
    <div class="stat-value text-primary">{length(@api_tokens)}</div>
  </div>

  <div class="stat bg-base-100 rounded-box shadow">
    <div class="stat-figure text-success">
      <.icon name="hero-check-circle" class="h-8 w-8" />
    </div>
    <div class="stat-title">活跃 Token</div>
    <div class="stat-value text-success">{@active_tokens_count}</div>
  </div>

  <div class="stat bg-base-100 rounded-box shadow">
    <div class="stat-figure text-error">
      <.icon name="hero-exclamation-triangle" class="h-8 w-8" />
    </div>
    <div class="stat-title">过期 Token</div>
    <div class="stat-value text-error">{@expired_tokens_count}</div>
  </div>

  <div class="stat bg-base-100 rounded-box shadow">
    <div class="stat-figure text-info">
      <.icon name="hero-chart-bar" class="h-8 w-8" />
    </div>
    <div class="stat-title">今日使用</div>
    <div class="stat-value text-info">{@today_usage_count}</div>
  </div>
</div>
```

### 创建/编辑 Modal
```elixir
<.modal id="token-modal" show={@show_modal} on_cancel={JS.hide(to: "#token-modal")}>
  <:header>
    <h3 class="text-lg font-semibold">
      {if @editing_token, do: "编辑 API Token", else: "创建 API Token"}
    </h3>
  </:header>

  <.simple_form for={@form} phx-submit="save_token" phx-change="validate_token">
    <.input field={@form[:name]} label="Token 名称" placeholder="例如：移动应用" />
    <.textarea_field
      id="description"
      name="description"
      value={@form[:description].value}
      label="描述"
      placeholder="可选：描述此 Token 的用途"
    />
    <.input field={@form[:expires_at]} type="datetime-local" label="过期时间" />

    <:actions>
      <.button variant="ghost" phx-click={JS.hide(to: "#token-modal")}>取消</.button>
      <.button>保存</.button>
    </:actions>
  </.simple_form>
</.modal>
```

### 删除确认 Modal
```elixir
<.modal id="delete-modal" show={@show_delete_modal} on_cancel={JS.hide(to: "#delete-modal")}>
  <:header>
    <h3 class="text-lg font-semibold text-error">删除 API Token</h3>
  </:header>

  <div class="space-y-4">
    <p>确定要删除 Token "<span class="font-medium">{@token_to_delete.name}</span>" 吗？</p>
    <p class="text-sm text-base-content/70">此操作不可撤销，使用此 Token 的应用将无法继续访问 API。</p>
  </div>

  <:footer>
    <.button variant="ghost" phx-click={JS.hide(to: "#delete-modal")}>取消</.button>
    <.button variant="danger" phx-click="confirm_delete">删除</.button>
  </:footer>
</.modal>
```

## 状态管理

### LiveView assigns 设计
```elixir
def mount(_params, _session, socket) do
  user = socket.assigns.current_user
  api_tokens = Account.list_user_api_tokens(user)

  {:ok,
   socket
   |> assign(:api_tokens, api_tokens)
   |> assign(:show_modal, false)
   |> assign(:show_delete_modal, false)
   |> assign(:editing_token, nil)
   |> assign(:token_to_delete, nil)
   |> assign(:form, to_form(%ApiToken{}))}
end
```

### 事件处理设计
```elixir
def handle_event("create_token", _params, socket) do
  {:noreply,
   socket
   |> assign(:show_modal, true)
   |> assign(:editing_token, nil)
   |> assign(:form, to_form(%ApiToken{}))}
end

def handle_event("edit_token", %{"id" => id}, socket) do
  token = Account.get_api_token!(id)
  {:noreply,
   socket
   |> assign(:show_modal, true)
   |> assign(:editing_token, token)
   |> assign(:form, to_form(token))}
end

def handle_event("save_token", %{"api_token" => params}, socket) do
  user = socket.assigns.current_user

  case Account.create_api_token(user, params) do
    {:ok, token} ->
      {:noreply,
       socket
       |> assign(:api_tokens, [token | socket.assigns.api_tokens])
       |> assign(:show_modal, false)
       |> put_flash(:info, "API Token 创建成功")}

    {:error, changeset} ->
      {:noreply, assign(socket, :form, to_form(changeset))}
  end
end
```

## 配置要求

### 数据库迁移
```elixir
defmodule Vmemo.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def change do
    # API Tokens 表（安全存储）
    create table(:api_tokens) do
      add :token_hash, :string, null: false  # 只存储 token 的 hash
      add :name, :string, null: false
      add :description, :text
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :is_active, :boolean, default: true, null: false
      add :created_at, :utc_datetime  # 创建时间，用于 token 显示
      add :user_id, references(:account_users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:api_tokens, [:token_hash])
    create index(:api_tokens, [:user_id])
    create index(:api_tokens, [:expires_at])
    create index(:api_tokens, [:is_active])

    # API Token 使用记录表（软删除）
    create table(:api_token_usage_logs) do
      add :action, :string, null: false  # "create", "used", "revoked", "expired"
      add :ip_address, :string
      add :user_agent, :text
      add :endpoint, :string  # API 端点
      add :method, :string   # HTTP 方法
      add :status_code, :integer  # HTTP 状态码
      add :response_time_ms, :integer  # 响应时间（毫秒）
      add :request_size_bytes, :integer  # 请求大小
      add :response_size_bytes, :integer  # 响应大小
      add :error_message, :text  # 错误信息
      add :deleted_at, :utc_datetime  # 软删除时间戳
      add :api_token_id, references(:api_tokens, on_delete: :delete_all), null: false
      add :user_id, references(:account_users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:api_token_usage_logs, [:api_token_id])
    create index(:api_token_usage_logs, [:user_id])
    create index(:api_token_usage_logs, [:action])
    create index(:api_token_usage_logs, [:inserted_at])
    create index(:api_token_usage_logs, [:status_code])
    create index(:api_token_usage_logs, [:endpoint])
    create index(:api_token_usage_logs, [:deleted_at])  # 软删除索引
  end
end
```

### 环境配置
```elixir
# config/config.exs
config :vmemo,
  api_token_prefix: "vmemo_",
  api_token_length: 32,
  default_token_expiry_days: 365
```

## 测试策略

### 单元测试
- ApiToken schema 验证
- Account 模块 CRUD 函数
- Token 生成和验证逻辑

### LiveView 测试
- 页面渲染测试
- 用户交互测试
- 错误处理测试

### 集成测试
- 完整的 Token 管理流程
- 权限验证测试
- 并发操作测试

## 监控和日志

### 关键指标
- Token 创建/删除频率
- Token 使用频率
- 过期 Token 数量
- 用户活跃度

### 日志记录
- Token 创建/删除操作
- Token 使用记录
- 异常操作记录

## 部署考虑

### 生产环境
- Token 存储加密
- 定期清理过期 Token
- 监控异常使用模式

### 扩展性
- 支持 Token 权限范围
- 支持 Token 使用统计
- 支持批量操作

## 总结

这个计划提供了一个完整的 **独立 API Token CRUD LiveView UI 页面** 开发方案，通过创建专门的 `/users/tokens` 页面，提供直观的 Token 管理体验。

### 🎯 **核心优势**
1. **功能独立性**: 专门的页面，不与其他功能混合，职责清晰
2. **用户体验优秀**: 充足的操作空间，完整的 CRUD 界面，流畅的交互流程
3. **安全性完备**: 完善的权限控制、Token 安全处理和过期管理
4. **可维护性强**: 清晰的代码结构，模块化设计，易于调试和扩展
5. **可扩展性好**: 为未来的 API 管理功能（如使用统计、权限范围等）预留空间
6. **🆕 使用记录功能**: 完整记录 Token 的创建、使用、撤销等操作历史
7. **🔒 安全存储**: Token 只存储 hash，创建时仅显示一次完整内容
8. **🗑️ 软删除**: 使用记录支持软删除，数据保留但用户不可见

### 📊 **技术特点**
- **独立路由**: `/users/tokens` 专门页面
- **完整 CRUD**: 创建、查看、编辑、删除、复制、状态管理
- **🆕 使用记录**: 详细记录每次 API 调用的信息（时间、端点、状态码、响应时间等）
- **🆕 统计分析**: 使用统计卡片，显示总数、活跃、过期、今日使用等数据
- **🆕 记录筛选**: 支持按时间、操作类型、状态码等条件筛选使用记录
- **🔒 安全存储**: Token 只存储 SHA256 hash，原始 token 仅创建时显示
- **🗑️ 软删除**: 使用记录支持软删除，保留审计数据
- **响应式设计**: 支持桌面端和移动端
- **组件复用**: 最大化利用现有 CoreComponents
- **状态管理**: 清晰的 LiveView assigns 和事件处理

### 🔄 **与 Upload API 的完美配合**
- 用户通过此页面创建和管理 API Token
- 使用 Token 调用 Upload Public API 上传图片
- **🆕 实时查看 Token 使用记录**：包括每次 API 调用的详细信息
- **🆕 监控 API 性能**：响应时间、状态码、错误信息等
- **🆕 安全审计**：IP 地址、用户代理、操作时间等安全相关信息
- **🔒 安全验证**：通过 hash 验证 Token 有效性
- 完整的 Token 生命周期管理

### 📈 **新增功能亮点**
- **使用记录表**: 记录每次 API 调用的详细信息
- **统计仪表板**: 直观显示 Token 使用情况
- **记录筛选**: 支持多维度筛选和搜索
- **性能监控**: 响应时间、请求大小等性能指标
- **安全审计**: IP 地址、用户代理等安全信息
- **导出功能**: 支持 CSV/JSON 格式导出使用记录
- **🔒 Token 安全**: 只存储 hash，创建时仅显示一次
- **🗑️ 软删除**: 使用记录软删除，保留审计数据

**预计总开发时间**: 7-11 天（增加了使用记录功能），具体取决于测试和优化的深度。这个独立页面将为用户提供完整的 API Token 管理能力，是 Upload Public API 功能的重要支撑，同时提供强大的使用记录和监控功能，以及企业级的安全保障。

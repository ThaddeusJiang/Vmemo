# Upload Public API 开发计划

## 问题分析

### 当前状态
- 项目已有完整的照片上传功能（基于 LiveView）
- 使用 Ash Framework 进行数据管理
- 已有用户认证系统（基于 session token）
- 文件存储使用本地文件系统
- 支持多种图片格式（.png .jpg .jpeg .gif .webp）
- 已有 Typesense 搜索集成

### 需求定义
1. **API 端点**: 提供 RESTful API 供外部应用上传图片
2. **认证方式**: 支持 API Token 认证
3. **文件处理**: 复用现有的文件存储和数据库逻辑
4. **响应格式**: 标准 JSON 响应
5. **错误处理**: 完善的错误信息和状态码

## 方案对比

### 方案 1: 扩展现有 Controller 架构
**优点**:
- 复用现有的 PhotoService 和 Ash 资源
- 保持代码一致性
- 易于维护

**缺点**:
- 需要处理 multipart/form-data
- 需要实现 API Token 认证

### 方案 2: 创建独立的 API 模块
**优点**:
- 完全独立，不影响现有功能
- 可以专门优化 API 性能
- 易于版本管理

**缺点**:
- 代码重复
- 维护成本增加

### 方案 3: 使用 Phoenix LiveView 的 API 模式
**优点**:
- 复用 LiveView 的上传逻辑
- 统一的错误处理

**缺点**:
- LiveView 主要面向 WebSocket，不适合纯 API
- 性能开销

## 技术选型

**选择方案 1: 扩展现有 Controller 架构**

理由：
- 最大化代码复用
- 保持架构一致性
- 符合 Phoenix 最佳实践
- 易于测试和维护

## 架构设计

### 1. API 路由设计
```elixir
scope "/api/v1", VmemoWeb.Api.V1 do
  pipe_through [:api, :api_auth]

  post "/photos", PhotoController, :create
  get "/photos/:id", PhotoController, :show
  delete "/photos/:id", PhotoController, :delete
end
```

### 2. 认证系统设计
```elixir
# API Token 认证 Pipeline
pipeline :api_auth do
  plug VmemoWeb.ApiAuth
end

# API Token 验证逻辑
defmodule VmemoWeb.ApiAuth do
  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> verify_token(conn, token)
      _ -> unauthorized(conn)
    end
  end
end
```

### 3. 数据流设计
```
客户端请求
  ↓
API Controller 接收 multipart/form-data
  ↓
验证 API Token
  ↓
处理文件上传
  ↓
调用 PhotoService.cp_file
  ↓
调用 Photo.create_with_sync
  ↓
触发 Oban job 同步到 Typesense
  ↓
返回 JSON 响应
```

### 4. 响应格式设计
```json
// 成功响应
{
  "status": "success",
  "data": {
    "id": "uuid",
    "url": "/storage/v1/user_id/photos/filename",
    "note": "optional note",
    "inserted_at": "2025-10-25T10:30:00Z"
  }
}

// 错误响应
{
  "status": "error",
  "error": {
    "code": "INVALID_FILE_TYPE",
    "message": "Only image files are allowed"
  }
}
```

## 风险评估

### 技术风险
1. **文件大小限制**: 需要配置合适的文件大小限制
2. **并发上传**: 大量并发上传可能影响性能
3. **存储空间**: 需要监控磁盘使用情况
4. **API 滥用**: 需要实现速率限制

### 安全风险
1. **文件类型验证**: 确保只允许图片文件
2. **文件内容验证**: 验证文件确实是图片
3. **API Token 安全**: 实现安全的 token 生成和验证
4. **用户隔离**: 确保用户只能访问自己的文件

### 性能风险
1. **Base64 编码**: 大文件转换为 base64 可能消耗内存
2. **数据库写入**: 大量上传可能影响数据库性能
3. **Typesense 同步**: 异步任务队列可能积压

## 实现计划

### 阶段 1: 基础 API 框架 (1-2 天)
- [ ] 创建 API 路由和 pipeline
- [ ] 实现 API Token 认证系统
- [ ] 创建基础的 PhotoController
- [ ] 实现基本的错误处理

### 阶段 2: 文件上传功能 (2-3 天)
- [ ] 实现 multipart/form-data 处理
- [ ] 集成现有的 PhotoService
- [ ] 实现文件类型和大小验证
- [ ] 添加文件内容验证

### 阶段 3: 完善功能 (1-2 天)
- [ ] 实现照片查询和删除 API
- [ ] 添加 API 文档
- [ ] 实现速率限制
- [ ] 添加监控和日志

### 阶段 4: 测试和优化 (1-2 天)
- [ ] 编写单元测试
- [ ] 编写集成测试
- [ ] 性能测试和优化
- [ ] 安全测试

## 技术细节

### API Token 管理
```elixir
# 用户 API Token 表
defmodule Vmemo.Account.ApiToken do
  use Ecto.Schema

  schema "api_tokens" do
    field :token, :string
    field :name, :string
    field :expires_at, :utc_datetime
    belongs_to :user, Vmemo.Account.User

    timestamps()
  end
end
```

### 文件验证
```elixir
defp validate_image_file(path) do
  case File.read(path) do
    {:ok, content} ->
      # 检查文件头
      case content do
        <<0x89, 0x50, 0x4E, 0x47, _::binary>> -> :ok  # PNG
        <<0xFF, 0xD8, 0xFF, _::binary>> -> :ok        # JPEG
        <<0x47, 0x49, 0x46, _::binary>> -> :ok         # GIF
        _ -> {:error, "Invalid image format"}
      end
    {:error, reason} -> {:error, reason}
  end
end
```

### 错误处理
```elixir
defp handle_error(conn, :invalid_file_type) do
  conn
  |> put_status(400)
  |> json(%{
    status: "error",
    error: %{
      code: "INVALID_FILE_TYPE",
      message: "Only image files are allowed"
    }
  })
end
```

## 配置要求

### 环境变量
```elixir
# config/runtime.exs
config :vmemo,
  api_token_secret: System.get_env("API_TOKEN_SECRET"),
  max_file_size: System.get_env("MAX_FILE_SIZE", "10MB") |> parse_size(),
  allowed_file_types: ~w(.png .jpg .jpeg .gif .webp)
```

### 数据库迁移
```elixir
defmodule Vmemo.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens) do
      add :token, :string, null: false
      add :name, :string, null: false
      add :expires_at, :utc_datetime
      add :user_id, references(:account_users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:api_tokens, [:token])
    create index(:api_tokens, [:user_id])
  end
end
```

## 测试策略

### 单元测试
- API Token 生成和验证
- 文件类型验证
- 错误处理逻辑

### 集成测试
- 完整的文件上传流程
- 认证失败场景
- 文件大小超限场景

### 性能测试
- 并发上传测试
- 大文件上传测试
- 内存使用监控

## 监控和日志

### 关键指标
- API 请求数量和响应时间
- 文件上传成功率
- 存储空间使用情况
- API Token 使用情况

### 日志记录
- 所有 API 请求
- 文件上传操作
- 认证失败尝试
- 错误和异常

## 部署考虑

### 生产环境
- 配置合适的文件大小限制
- 设置 API 速率限制
- 监控存储空间
- 备份策略

### 扩展性
- 考虑使用对象存储（如 S3）
- 实现 CDN 加速
- 数据库读写分离
- 缓存策略

## 总结

这个计划提供了一个完整的 Upload Public API 开发方案，通过扩展现有的 Controller 架构，最大化代码复用，同时保持系统的安全性和性能。主要优势包括：

1. **复用现有基础设施**: 充分利用现有的 PhotoService、Ash 资源和 Typesense 集成
2. **安全性**: 实现 API Token 认证和文件验证
3. **可维护性**: 保持代码结构一致性
4. **可扩展性**: 为未来的功能扩展预留空间

预计总开发时间：5-9 天，具体取决于测试和优化的深度。

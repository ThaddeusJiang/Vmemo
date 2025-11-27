# Vmemo

Vmemo 是一个视觉记忆应用，帮助用户通过照片捕捉和组织生活瞬间。支持 AI 驱动的图片搜索、自动描述生成和 Public API。

## 功能特性

- 📸 **照片上传和管理**: 支持多图上传、拖拽上传、剪贴板粘贴
- 🔍 **智能搜索**: 文本搜索和图片相似度搜索（基于 CLIP 模型）
- 🤖 **AI 增强**: 自动生成图片描述和 OCR 文本提取
- 🔐 **API Token 管理**: 完整的 API Token CRUD 功能，支持过期时间设置
- 🌐 **Public API**: RESTful API 支持外部应用集成
- 📱 **响应式设计**: 支持桌面和移动端

## 快速开始

### 前置要求

- **mise**: 用于管理 Elixir 和 Erlang 版本
- **Docker**: 用于运行依赖服务（PostgreSQL, Typesense）

#### 安装 mise（如果尚未安装）

```bash
# macOS
brew install mise

# 或使用官方安装脚本
curl https://mise.run | sh
```

#### 安装项目所需的 Elixir 和 Erlang 版本

项目使用 `mise` 管理版本，版本定义在 `.tool-versions` 文件中：

```bash
# 进入项目目录后，mise 会自动安装所需版本
cd /path/to/vmemo
mise install
```

当前项目要求：

- Elixir: 1.19.2-otp-28
- Erlang: 28.1.1

### 1. 启动依赖服务

```bash
docker compose up -d
```

### 2. 安装依赖并初始化数据库

```bash
mix setup
```

### 3. 启动 Phoenix 服务器

```bash
iex -S mix phx.server
```

现在可以访问 [`localhost:4000`](http://localhost:4000)

## Public API

Vmemo 提供 RESTful API 供外部应用集成。

### 认证

所有 API 请求需要在 Header 中包含 API Token：

```bash
Authorization: Bearer vmemo_your_token_here
```

### 创建 API Token

1. 登录 Vmemo
2. 访问 `/tokens` 页面
3. 点击"创建新 Token"
4. 设置名称、描述和过期时间
5. **重要**: 创建后立即复制保存 Token，之后无法再次查看完整内容

### API 端点

#### 上传照片

```bash
POST /api/v1/photos
Content-Type: multipart/form-data

curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_your_token" \
  -F "file=@/path/to/image.jpg" \
  -F "note=My photo description"
```

**响应示例**:

```json
{
  "status": "success",
  "data": {
    "id": "photo-uuid",
    "url": "/storage/v1/<user_id>/photos/filename.jpg",
    "note": "My photo description",
    "inserted_at": "2025-01-26T10:30:00Z"
  }
}
```

#### 获取照片信息

```bash
GET /api/v1/photos/:id

curl -X GET http://localhost:4000/api/v1/photos/photo-uuid \
  -H "Authorization: Bearer vmemo_your_token"
```

#### 删除照片

```bash
DELETE /api/v1/photos/:id

curl -X DELETE http://localhost:4000/api/v1/photos/photo-uuid \
  -H "Authorization: Bearer vmemo_your_token"
```

### 错误响应

```json
{
  "status": "error",
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing API token"
  }
}
```

**常见错误码**:

- `401`: 未认证或 Token 无效/过期
- `404`: 资源不存在
- `400`: 请求参数错误
- `500`: 服务器内部错误

### 文件限制

- **支持格式**: PNG, JPG, JPEG, GIF, WEBP
- **文件大小**: 建议不超过 10MB（可配置）

## 配置

### 环境变量

#### 开发环境 (dev)

开发环境使用 `config/dev.exs` 中的默认配置，**无需设置环境变量**。

#### 测试环境 (test)

测试环境使用 `config/test.exs` 中的默认配置，大部分环境变量都有默认值：

```bash
# 可选：Typesense 配置（默认: http://localhost:8766 / xyz）
TYPESENSE_URL=http://localhost:8766
TYPESENSE_API_KEY=xyz
```

#### 生产环境 (prod)

生产环境**必须**设置以下环境变量（通过 `config/runtime.exs` 加载）：

**必需环境变量**：

```bash
# 数据库连接（必需）
DATABASE_URL=postgresql://user:pass@host/database

# 管理员 Token（必需）
ADMIN_TOKEN=your_secure_admin_token

# Phoenix 密钥（必需）
SECRET_KEY_BASE=your_secret_key_base
# 生成方式: mix phx.gen.secret

# Sentry 错误监控（必需）
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id

# 邮件服务 Resend（必需）
RESEND_API_KEY=your_resend_api_key

# 注意: JWT_SIGNING_SECRET 已合并到 SECRET_KEY_BASE
# JWT token 签名现在使用 SECRET_KEY_BASE，无需单独配置
```

**可选环境变量**：

```bash
# PostgreSQL 连接池大小（默认: 10）
POOL_SIZE=10

# 启用 IPv6（默认: false）
ECTO_IPV6=false

# Typesense 搜索引擎
TYPESENSE_URL=http://typesense-host:8108
TYPESENSE_API_KEY=your_typesense_api_key

# Moondream AI 服务
MOONDREAM_URL=http://moondream-host:2020/v1

# Phoenix 主机名（默认: vmemo.app）
PHX_HOST=vmemo.app

# 服务端口（默认: 4000）
PORT=4000

# DNS 集群查询（用于集群部署）
DNS_CLUSTER_QUERY=

# 启用 Phoenix 服务器（用于 release 模式）
PHX_SERVER=true
```

### 可选配置

```elixir
# config/runtime.exs
config :vmemo,
  max_file_size: 10 * 1024 * 1024,  # 10MB
  allowed_file_types: ~w(.png .jpg .jpeg .gif .webp)
```

## 开发

### 运行测试

```bash
mix test
```

### 代码格式化

```bash
mix format
```

### 类型检查

```bash
mix format --check-formatted
```

## 技术栈

- **框架**: Elixir Phoenix + LiveView
- **语言版本**: Elixir 1.19.2, Erlang/OTP 28
- **版本管理**: mise (推荐)
- **数据库**: PostgreSQL
- **搜索引擎**: Typesense (CLIP 模型)
- **认证**: Ash Authentication
- **任务队列**: Oban
- **邮件**: Swoosh + Resend
- **前端**: Tailwind CSS + DaisyUI

## 文档

- [Public API 详细文档](docs/public-api.md)
- [API Token 管理指南](docs/api-tokens.md)
- [Release Notes](docs/RELEASE-NOTES.md)
- [Migration Guide](docs/MIGRATION-GUIDE.md)
- [Test Plan](docs/TEST-PLAN.md)
- [Code Review](docs/CODE-REVIEW.md)

## 部署

### Zeabur 一键部署

[![Deploy on Zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/H3EL85)

### Docker 部署

```bash
# 构建镜像
docker build -t vmemo:latest .

# 运行容器（必需环境变量）
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE=your_secret_key_base \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  -e ADMIN_TOKEN=your_secure_admin_token \
  -e SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id \
  -e RESEND_API_KEY=your_resend_api_key \
  -e TYPESENSE_URL=http://typesense-host:8108 \
  -e TYPESENSE_API_KEY=your_typesense_api_key \
  -e PHX_SERVER=true \
  vmemo:latest
```

**注意**: 生产环境部署时，建议使用 `.env` 文件或 Docker secrets 来管理敏感信息，而不是直接在命令行中暴露。

### 本地预览（Local Preview）

用于验证 Docker 构建和运行的本地测试环境：

```bash
# 1. 构建镜像
docker build -t vmemo:test .

# 2. 启动依赖服务（如果尚未启动）
docker compose up -d

# 3. 运行容器进行本地预览
docker run --rm \
  -e PHX_SERVER=true \
  -e DATABASE_URL="ecto://postgres:postgres@host.docker.internal:54321/vmemo_dev" \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e ADMIN_TOKEN="test_admin_token" \
  -e SENTRY_DSN="https://test@test.ingest.sentry.io/123456" \
  -e RESEND_API_KEY="test_resend_key" \
  -e PHX_HOST="vmemo.orb.local" \
  -e PORT=4000 \
  -p 4000:4000 \
  vmemo:test
```

**本地预览说明**：

- 使用 `vmemo.orb.local` 作为 host（适用于 OrbStack 本地域名系统）
- 数据库连接使用 `host.docker.internal:54321` 访问本地 Docker Compose 服务
- 测试环境变量使用占位符值，仅用于验证构建和运行
- 访问地址：`http://vmemo.orb.local:4000`（需要配置 hosts 或使用 OrbStack）

**验证步骤**：

1. ✅ **Docker Build**: 镜像构建成功，无错误
2. ✅ **Docker Run**: 容器启动成功，应用正常运行
3. ✅ **功能验证**: Phoenix LiveView 应用在容器中正常工作

## 安全注意事项

1. **必需环境变量**: 生产环境必须设置所有必需的环境变量（见上方配置部分）
   - `SECRET_KEY_BASE`: 用于加密 cookies、会话和 JWT token 签名，使用 `mix phx.gen.secret` 生成
   - `ADMIN_TOKEN`: 管理员访问令牌，必须使用强随机值
   - `SENTRY_DSN`: 错误监控服务配置
   - `RESEND_API_KEY`: 邮件服务 API 密钥
   - `DATABASE_URL`: 数据库连接字符串
2. **API Token**: 创建后立即保存，无法再次查看
3. **Token 过期**: 建议设置合理的过期时间
4. **速率限制**: 生产环境建议启用 API 速率限制
5. **HTTPS**: 生产环境必须使用 HTTPS
6. **环境变量管理**: 不要将敏感信息提交到版本控制系统，使用环境变量或密钥管理服务

## 贡献

欢迎提交 Issue 和 Pull Request！

## License

MIT

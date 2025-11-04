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

```bash
# 数据库
DATABASE_URL=postgresql://user:pass@localhost/vmemo_dev

# Typesense 搜索引擎
TYPESENSE_URL=http://localhost:8108
TYPESENSE_API_KEY=your_typesense_key

# 邮件服务（Resend）
RESEND_API_KEY=your_resend_key

# Phoenix
SECRET_KEY_BASE=your_secret_key
PHX_HOST=localhost

# JWT 签名密钥（重要：生产环境必须设置）
JWT_SIGNING_SECRET=your_jwt_secret
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

# 运行容器
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE=your_secret \
  -e DATABASE_URL=postgresql://... \
  -e TYPESENSE_URL=http://... \
  -e TYPESENSE_API_KEY=your_key \
  -e JWT_SIGNING_SECRET=your_jwt_secret \
  -e RESEND_API_KEY=your_key \
  vmemo:latest
```

## 安全注意事项

1. **JWT_SIGNING_SECRET**: 生产环境必须设置强随机密钥
2. **API Token**: 创建后立即保存，无法再次查看
3. **Token 过期**: 建议设置合理的过期时间
4. **速率限制**: 生产环境建议启用 API 速率限制
5. **HTTPS**: 生产环境必须使用 HTTPS

## 贡献

欢迎提交 Issue 和 Pull Request！

## License

MIT

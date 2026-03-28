# 2025-11-27 测试 Docker Build 和 Run

## 任务目标

测试项目的 Docker 构建和运行功能，确保：

- Docker 镜像能够成功构建
- 容器能够正常启动
- 应用能够正常运行

## 计划阶段

### 需求分析

- **目标**：验证 Dockerfile 配置正确性，确保生产环境可以正常构建和运行
- **约束条件**：
  - 使用项目现有的 Dockerfile
  - 需要检查必要的环境变量配置
  - 验证容器启动流程
- **验收标准**：
  - Docker build 成功完成
  - Docker run 能够启动容器
  - 应用能够正常响应（如果配置了数据库等依赖）

### 技术方案

- 使用项目现有的多阶段构建 Dockerfile
- 构建镜像并测试运行
- 检查日志和错误信息

### 风险评估

- Dockerfile 可能缺少必要的环境变量
- 运行时可能需要数据库连接等外部依赖
- 端口配置可能需要调整

## 执行记录

### 阶段一：检查 Dockerfile 配置

- **时间**：2025-11-27
- **操作**：检查 Dockerfile 和 .dockerignore 文件
- **结果**：
  - Dockerfile 使用多阶段构建（builder + runner）
  - 基于 elixir:1.19.2 镜像
  - 构建步骤包括：deps.get、compile、assets.deploy
  - 运行阶段使用 `mix phx.server` 启动
- **问题**：无
- **解决方案**：无

### 阶段二：执行 Docker Build

- **时间**：2025-11-27 14:42
- **操作**：执行 `docker build -t vmemo:test .`
- **结果**：构建成功完成
  - 多阶段构建正常执行
  - 依赖下载和编译成功
  - 资源文件（tailwind、esbuild）构建成功
  - 镜像大小合理
- **问题**：
  - Dockerfile 中有 3 个警告：ENV 格式建议使用 `ENV key=value` 而不是 `ENV key value`（第 32-34 行）
- **解决方案**：警告不影响功能，但可以后续优化 Dockerfile 格式

### 阶段三：执行 Docker Run

- **时间**：2025-11-27 14:43
- **操作**：执行 docker run 命令测试容器启动
- **结果**：容器成功启动并运行
  - 应用在端口 4000 上成功启动
  - Phoenix LiveView socket 连接成功
  - 服务器日志显示正常运行
- **问题**：
  1. 首次运行：Sentry DSN 格式错误（缺少项目 ID）
  2. 运行中：Origin 检查警告（配置的 host 是 vmemo.app，但访问的是 localhost）
- **解决方案**：
  1. 使用正确的 Sentry DSN 格式：`https://test@test.ingest.sentry.io/123456`
  2. Origin 警告不影响功能，是配置问题，生产环境需要正确设置 PHX_HOST

## 测试记录

### Docker Build 测试结果

- ✅ **构建成功**：镜像 `vmemo:test` 成功构建
- ✅ **依赖安装**：所有 Elixir 依赖正常下载和编译
- ✅ **资源构建**：Tailwind CSS 和 esbuild 资源成功构建
- ⚠️ **警告**：3 个 ENV 格式警告（不影响功能）

### Docker Run 测试结果

- ✅ **容器启动**：容器成功启动
- ✅ **应用运行**：Phoenix 应用在端口 4000 上正常运行
- ✅ **LiveView**：LiveView socket 连接成功
- ⚠️ **配置警告**：Origin 检查警告（需要正确配置 PHX_HOST）

### 环境变量要求

应用需要以下环境变量才能正常运行：

- `PHX_SERVER=true` - 启用 Phoenix 服务器
- `DATABASE_URL` - 数据库连接字符串
- `SECRET_KEY_BASE` - 密钥（至少 64 字符）
- `ADMIN_PASSWORD` - 管理员密码
- `SENTRY_DSN` - Sentry DSN（格式：`https://key@host/project_id`）
- `RESEND_API_KEY` - Resend API 密钥
- `PORT` - 端口号（默认 4000）
- `PHX_HOST` - 主机名（默认 vmemo.app）
  - 本地预览可以使用：`vmemo.orb.local`

## 总结

- ✅ **Docker Build 测试通过**：镜像构建成功，所有步骤正常完成
- ✅ **Docker Run 测试通过**：容器能够成功启动并运行应用
- ✅ **功能验证**：Phoenix LiveView 应用在容器中正常运行
- 📝 **建议优化**：
  1. 修复 Dockerfile 中的 ENV 格式警告
  2. 在生产环境部署时正确配置 PHX_HOST 环境变量
  3. 确保数据库连接配置正确（使用 host.docker.internal 或 Docker 网络）

**结论**：Docker 构建和运行测试成功，应用可以在容器环境中正常运行。

## 本地预览配置

### 使用 vmemo.orb.local 作为 host

在本地预览时，可以使用 `PHX_HOST=vmemo.orb.local` 环境变量：

```bash
docker run --rm \
  -e PHX_SERVER=true \
  -e DATABASE_URL="postgres://postgres:postgres@host.docker.internal:54321/vmemo_dev" \
  -e SECRET_KEY_BASE="your_secret_key_base" \
  -e ADMIN_PASSWORD="test_admin_password" \
  -e SENTRY_DSN="https://test@test.ingest.sentry.io/123456" \
  -e RESEND_API_KEY="test_resend_key" \
  -e PHX_HOST="vmemo.orb.local" \
  -e PORT=4000 \
  -p 4000:4000 \
  vmemo:test
```

这样配置后，应用会使用 `vmemo.orb.local` 作为 host，可以避免 Origin 检查警告。

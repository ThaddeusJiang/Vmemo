# 2025-11-27 测试 Docker Build 和 Run

## 变更概述

测试并验证项目的 Docker 构建和运行功能，确保生产环境可以正常部署。同时添加本地预览配置说明，支持使用 `vmemo.orb.local` 作为 host。

## 背景

为了确保 Docker 镜像能够正确构建和运行，需要进行完整的测试验证。同时，本地开发时需要支持使用 OrbStack 的本地域名系统进行预览。

## 变更内容

### 1. Docker Build 测试

- ✅ 成功构建镜像 `vmemo:test`
- ✅ 多阶段构建正常执行（builder + runner）
- ✅ 依赖下载和编译成功
- ✅ 资源文件（Tailwind CSS、esbuild）构建成功
- ⚠️ 发现 3 个 ENV 格式警告（不影响功能）

### 2. Docker Run 测试

- ✅ 容器成功启动
- ✅ Phoenix 应用在端口 4000 上正常运行
- ✅ LiveView socket 连接成功
- ✅ 解决了 Sentry DSN 格式问题
- ⚠️ Origin 检查警告（通过配置 PHX_HOST 解决）

### 3. 本地预览配置

添加了使用 `vmemo.orb.local` 作为 host 的本地预览配置：

- 支持 OrbStack 本地域名系统
- 避免 Origin 检查警告
- 提供完整的 docker run 命令示例

### 4. 文档更新

- **README.md**: 添加"本地预览（Local Preview）"章节，包含完整的验证步骤
- **docs/tasks/todo/2025-11-27-test-docker-build-and-run.md**: 完整的工作记录文档

## 测试结果

### Docker Build
- ✅ 构建成功，无错误
- ✅ 所有依赖正常安装
- ✅ 资源文件构建成功

### Docker Run
- ✅ 容器启动成功
- ✅ 应用正常运行
- ✅ LiveView 功能正常

## 环境变量要求

应用需要以下环境变量才能正常运行：

- `PHX_SERVER=true` - 启用 Phoenix 服务器
- `DATABASE_URL` - 数据库连接字符串
- `SECRET_KEY_BASE` - 密钥（至少 64 字符）
- `ADMIN_TOKEN` - 管理员令牌
- `SENTRY_DSN` - Sentry DSN（格式：`https://key@host/project_id`）
- `RESEND_API_KEY` - Resend API 密钥
- `PORT` - 端口号（默认 4000）
- `PHX_HOST` - 主机名（默认 vmemo.app，本地预览可使用 vmemo.orb.local）

## 本地预览命令

```bash
# 构建镜像
docker build -t vmemo:test .

# 运行容器
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

## 影响

### 优势
- ✅ 验证了 Docker 构建和运行流程
- ✅ 提供了本地预览的完整配置
- ✅ 更新了文档，便于后续使用

### 注意事项
- ⚠️ Dockerfile 中有 ENV 格式警告（建议后续优化）
- ⚠️ 生产环境需要正确配置所有必需的环境变量
- ⚠️ 本地预览需要配置 hosts 或使用 OrbStack

## 相关任务

- [任务文档](tasks/todo/2025-11-27-test-docker-build-and-run.md)


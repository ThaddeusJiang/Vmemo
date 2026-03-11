# Docker 启动检查清单

本文档列出 Docker 容器启动前需要检查的所有配置项。

## ✅ 已修复的问题

### 1. 入口点脚本 (`rel/entrypoint.sh`)

- ✅ 自动解析 `DATABASE_URL` 环境变量
- ✅ 提取数据库密码用于 `pg_isready` 认证
- ✅ 等待数据库就绪（最多 60 次尝试）
- ✅ 运行数据库迁移（`mix ash_postgres.migrate`）
- ✅ 启动 Phoenix 服务器

### 2. Dockerfile 配置

- ✅ 安装 `postgresql-client`（用于 `pg_isready`）
- ✅ 复制入口点脚本到 `/usr/local/bin/entrypoint.sh`
- ✅ 设置执行权限
- ✅ 使用 `ENTRYPOINT + CMD` 模式

### 3. Zeabur 配置 (`others/zeabur/vmemo.yml`)

- ✅ 添加 `PHX_SERVER=true` 环境变量
- ✅ 添加 `ADMIN_TOKEN` 环境变量配置
- ✅ 添加 `SENTRY_DSN` 环境变量配置
- ✅ 保留其他必需环境变量（`SECRET_KEY_BASE`, `RESEND_API_KEY` 等）

## ⚠️ 需要用户配置的环境变量

在 Zeabur 部署时，用户**必须**设置以下环境变量：

### 必需环境变量

1. **SECRET_KEY_BASE** - Phoenix 密钥
   - 生成方式：`mix phx.gen.secret`
   - 用途：加密 cookies、会话和 JWT token 签名

2. **ADMIN_TOKEN** - 管理员令牌
   - 用途：管理员访问令牌
   - 建议：使用强随机值

3. **SENTRY_DSN** - Sentry 错误监控
   - 格式：`https://key@host/project_id`
   - 用途：错误监控和日志收集

4. **RESEND_API_KEY** - Resend 邮件服务
   - 用途：发送邮件通知

### 可选环境变量

- `OPENROUTER_API_KEY` - 如果使用聊天功能
- `MOONDREAM_URL` - Moondream AI 服务地址

## 🔍 启动流程验证

容器启动时会按以下顺序执行：

1. **解析 DATABASE_URL**
   ```
   从 DATABASE_URL 提取：
   - DB_HOST (数据库主机)
   - DB_PORT (数据库端口，默认 5432)
   - DB_USER (数据库用户)
   - DB_PASSWORD (数据库密码，用于 pg_isready)
   ```

2. **等待数据库就绪**
   ```
   使用 pg_isready 检查数据库连接
   - 最多尝试 60 次
   - 每次间隔 1 秒
   - 超时后容器退出
   ```

3. **运行数据库迁移**
   ```
   mix ash_postgres.migrate
   - 创建所有必需的表（包括 oban_jobs）
   - 如果迁移失败，容器退出
   ```

4. **启动 Phoenix 服务器**
   ```
   mix phx.server
   - 应用正常启动
   ```

## 🐛 常见问题排查

### 问题 1: 数据库连接超时

**症状**：容器启动时显示 "Timeout: Database is not ready after 60 attempts"

**可能原因**：
- `DATABASE_URL` 配置错误
- 数据库服务未启动
- 网络连接问题
- 防火墙阻止连接

**解决方法**：
1. 检查 `DATABASE_URL` 格式是否正确
2. 确认数据库服务正在运行
3. 检查网络连接和防火墙设置
4. 验证数据库用户权限

### 问题 2: 迁移失败

**症状**：容器启动时显示 "Migration failed!"

**可能原因**：
- 数据库权限不足
- 迁移文件错误
- 数据库版本不兼容

**解决方法**：
1. 查看容器日志：`docker logs <container_id>`
2. 检查数据库用户权限
3. 验证迁移文件是否正确
4. 检查数据库版本兼容性

### 问题 3: 环境变量缺失

**症状**：应用启动时抛出异常，提示环境变量缺失

**可能原因**：
- 必需环境变量未设置
- 环境变量名称拼写错误

**解决方法**：
1. 检查 `config/runtime.exs` 中列出的必需环境变量
2. 确认所有必需环境变量都已设置
3. 验证环境变量名称拼写正确

## 📝 测试建议

在部署到生产环境前，建议进行以下测试：

1. **本地 Docker 测试**
   ```bash
   docker build -t vmemo:test .
   docker run --rm \
     -e DATABASE_URL=postgresql://user:pass@host/database \
     -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
     -e ADMIN_TOKEN=test_token \
     -e SENTRY_DSN=https://test@test.ingest.sentry.io/123456 \
     -e RESEND_API_KEY=test_key \
     -e PHX_SERVER=true \
     vmemo:test
   ```

2. **检查容器日志**
   ```bash
   docker logs <container_id>
   ```

3. **验证数据库迁移**
   ```bash
   # 进入容器（如果容器正在运行）
   docker exec -it <container_id> /bin/bash
   # 检查 oban_jobs 表是否存在
   mix ash_postgres.migrate --dry-run
   ```

## ✅ 验证清单

在部署前，确认以下项目：

- [ ] `rel/entrypoint.sh` 文件存在且可执行
- [ ] Dockerfile 正确配置了入口点脚本
- [ ] Zeabur 配置包含所有必需环境变量
- [ ] 数据库服务已启动并可访问
- [ ] 所有必需环境变量已设置
- [ ] 测试环境验证通过

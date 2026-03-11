# Docker 最佳实践

本文档说明 Vmemo 项目在 Docker 容器部署中采用的最佳实践，特别是如何处理数据库迁移和容器启动问题。

## 问题背景

在服务器中启动 Docker 容器时，如果数据库表（如 `oban_jobs`）不存在，应用会启动失败。但由于容器没有正确启动，无法进入容器执行迁移命令，形成死循环。

## 解决方案

采用 **入口点脚本（Entrypoint Script）** 模式，在容器启动前自动处理：

1. **等待数据库就绪**
2. **运行数据库迁移**
3. **启动应用**

## 实现细节

### 1. 入口点脚本 (`rel/entrypoint.sh`)

脚本执行以下步骤：

```bash
# 1. 解析 DATABASE_URL 环境变量，提取数据库连接信息
# 2. 使用 pg_isready 等待数据库就绪（最多 60 次尝试）
# 3. 运行数据库迁移: mix ash_postgres.migrate
# 4. 启动 Phoenix 服务器: mix phx.server
```

**关键特性**：

- ✅ 自动解析 `DATABASE_URL` 环境变量
- ✅ 支持超时机制（60 秒）
- ✅ 迁移失败时容器会退出，便于排查问题
- ✅ 使用 `exec "$@"` 确保信号正确传递

### 2. Dockerfile 配置

```dockerfile
# 安装 postgresql-client 用于 pg_isready 命令
RUN apt-get install -y ... postgresql-client ...

# 复制并设置入口点脚本权限
COPY rel/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 使用 ENTRYPOINT + CMD 模式
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mix", "phx.server"]
```

## 使用方式

### 基本用法

```bash
docker run -p 4000:4000 \
  -e DATABASE_URL=postgresql://user:pass@host:port/database \
  -e SECRET_KEY_BASE=your_secret_key_base \
  -e ADMIN_TOKEN=your_admin_token \
  -e SENTRY_DSN=your_sentry_dsn \
  -e RESEND_API_KEY=your_resend_key \
  -e PHX_SERVER=true \
  vmemo:latest
```

容器启动时会自动：

1. 等待数据库就绪
2. 运行所有待执行的迁移（包括 Oban 表创建）
3. 启动 Phoenix 服务器

### 自定义命令

如果需要执行其他命令（如手动运行迁移），可以覆盖 CMD：

```bash
# 只运行迁移，不启动服务器
docker run --rm \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  vmemo:latest \
  mix ash_postgres.migrate

# 进入交互式 shell
docker run --rm -it \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  vmemo:latest \
  /bin/bash
```

## 优势

### 1. 自动化

- ✅ 无需手动执行迁移命令
- ✅ 无需进入容器调试
- ✅ 容器启动即用

### 2. 可靠性

- ✅ 确保数据库就绪后再启动应用
- ✅ 迁移失败时容器退出，避免运行不完整状态的应用
- ✅ 清晰的错误信息，便于排查问题

### 3. 符合 Docker 最佳实践

- ✅ 使用 ENTRYPOINT + CMD 模式
- ✅ 信号正确传递（使用 `exec`）
- ✅ 单一职责：入口点脚本只负责启动前准备

## 故障排查

### 数据库连接超时

如果看到 "Timeout: Database is not ready after 60 attempts"：

1. 检查 `DATABASE_URL` 是否正确
2. 确认数据库服务正在运行
3. 检查网络连接和防火墙设置
4. 验证数据库用户权限

### 迁移失败

如果看到 "Migration failed!"：

1. 查看容器日志获取详细错误信息：`docker logs <container_id>`
2. 检查数据库连接权限
3. 确认迁移文件是否正确
4. 检查数据库版本兼容性

### 手动调试

如果需要手动调试，可以覆盖入口点：

```bash
# 跳过入口点脚本，直接执行命令
docker run --rm -it \
  --entrypoint /bin/bash \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  vmemo:latest

# 在容器内手动执行
mix ash_postgres.migrate
mix phx.server
```

## 参考

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Oban Documentation](https://hexdocs.pm/oban/)

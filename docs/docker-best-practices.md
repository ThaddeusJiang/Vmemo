# Docker 最佳实践

本文档说明 Vmemo 项目在 Docker 容器部署中采用的最佳实践，特别是如何处理数据库迁移、Typesense schema migration 和容器启动问题。

## 问题背景

在服务器中启动 Docker 容器时，如果数据库表（如 `oban_jobs`）不存在，应用会启动失败。但由于容器没有正确启动，无法进入容器执行迁移命令，形成死循环。

## 解决方案

采用 **入口点脚本（Entrypoint Script）** 模式，在容器启动时自动处理：

1. **运行 Postgres 迁移**
2. **运行 Typesense 迁移**
3. **启动应用**

## 实现细节

### 1. 入口点脚本 (`rel/entrypoint.sh`)

脚本执行以下步骤：

```bash
# 1. 运行数据库迁移: mix ash.migrate
# 2. 运行 Typesense 迁移: mix ts.migrate
# 3. 启动应用: exec "$@"
```

**关键特性**：

- ✅ 直接复用项目内 Mix task
- ✅ Postgres 与 Typesense migration 在同一入口中串行执行
- ✅ 迁移失败时容器会退出，便于排查问题
- ✅ runner 保留 Mix，便于在 prod hosting 中直接执行 Elixir 任务

### 2. Dockerfile 配置

```dockerfile
COPY rel/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mix", "phx.server"]
```

## 使用方式

### 基本用法

```bash
docker run -p 4000:4000 \
  -e DATABASE_URL=postgresql://user:pass@host:port/database \
  -e SECRET_KEY_BASE=your_secret_key_base \
  -e ADMIN_PASSWORD=your_admin_password \
  -e SENTRY_DSN=your_sentry_dsn \
  -e RESEND_API_KEY=your_resend_key \
  -e PHX_SERVER=true \
  vmemo:latest
```

容器启动时会自动：

1. 运行 `mix ash.migrate`
2. 运行 `mix ts.migrate`
3. 启动 Phoenix 服务器

### 自定义命令

如果需要执行其他命令（如手动运行迁移），可以覆盖默认命令：

```bash
# 只运行迁移，不启动服务器
docker run --rm \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  vmemo:latest \
  mix ash.migrate

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

- ✅ 迁移失败时容器退出，避免运行不完整状态的应用
- ✅ Typesense schema 与 Postgres schema 在启动时一起对齐
- ✅ 清晰的错误信息，便于排查问题

### 3. 符合 Docker 最佳实践

- ✅ `ENTRYPOINT` 负责启动前准备，`CMD` 负责主进程
- ✅ 镜像与本地开发都复用 Mix
- ✅ 可以方便覆盖 `CMD` 做临时运维任务

### 迁移失败

如果看到 "Migration failed!"：

1. 查看容器日志获取详细错误信息：`docker logs <container_id>`
2. 检查数据库连接权限
3. 确认迁移文件是否正确
4. 检查数据库版本兼容性

### 手动调试

如果需要手动调试，可以覆盖入口点：

```bash
docker run --rm -it \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  --entrypoint /bin/bash \
  vmemo:latest

# 在容器内手动执行
mix ash.migrate
mix ts.migrate
mix phx.server
```

## 参考

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Oban Documentation](https://hexdocs.pm/oban/)

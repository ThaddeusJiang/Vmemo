# Docker 最佳实践

本文档说明 Vmemo 在 Docker 部署中推荐的 release 启动方案，重点覆盖迁移与启动顺序。

## 核心原则

1. 使用单一 prod Dockerfile
2. 使用 Elixir release 启动（`bin/vmemo start`）
3. 在入口点执行统一 release 迁移（包含 Postgres + Typesense）

## 入口点脚本

[`rel/entrypoint.sh`](/Users/amami/git/my-personal-2026/Vmemo/rel/entrypoint.sh)：

```bash
/app/bin/vmemo eval "Vmemo.Release.migrate()"
exec /app/bin/vmemo "$@"
```

说明：

- 迁移失败时立即退出，避免不完整状态启动
- 主进程始终为 release 命令（默认 `start`）

## Dockerfile 模式

```dockerfile
RUN mix release

COPY --from=builder /app/_build/prod/rel/vmemo /app

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start"]
```

## 使用示例

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

容器启动顺序：

1. `bin/vmemo eval "Vmemo.Release.migrate()"`
2. `bin/vmemo start`

## 手动运维

如需手动执行迁移：

```bash
docker run --rm \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  vmemo:latest \
  eval "Vmemo.Release.migrate()"
```

如需交互调试：

```bash
docker run --rm -it \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  --entrypoint /bin/bash \
  vmemo:latest
```

## 参考

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)

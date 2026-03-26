# 构建和运行

Docker 只保留单一的 prod 镜像入口：

- 根目录 [`Dockerfile`](/Users/amami/git/my-personal-2026/Vmemo/Dockerfile) 同时用于本地 Docker 运行和 GitHub Actions publish，统一使用 `MIX_ENV=prod`

不再维护单独的 dev Docker 环境或额外的 Dockerfile 变体。

## 本地依赖服务

[`_local/docker-compose.yml`](/Users/amami/git/my-personal-2026/Vmemo/_local/docker-compose.yml) 用于启动本地依赖服务；应用可以运行在宿主机上，也可以单独以 prod 容器方式运行。

启动依赖服务：

```bash
docker compose -f _local/docker-compose.yml up -d postgres typesense
```

## 本地运行 prod 容器

先构建 prod 镜像：

```bash
docker build -t vmemo:local .
```

然后运行：

```bash
docker run --rm -p 4000:4000 \
  -e SECRET_KEY_BASE=your_secret_key_base \
  -e DATABASE_URL=ecto://postgres:postgres@host.docker.internal:54321/vmemo_dev \
  -e ADMIN_PASSWORD=test_admin_password \
  -e SENTRY_DSN=https://test@example.ingest.sentry.io/123456 \
  -e SENTRY_ENV=staging \
  -e RESEND_API_KEY=test_resend_key \
  -e TYPESENSE_URL=http://host.docker.internal:8766 \
  -e TYPESENSE_API_KEY=xyz \
  -e PHX_HOST=localhost \
  -e PHX_SERVER=true \
  vmemo:local
```

容器会以 `MIX_ENV=prod` 启动，并在入口脚本中先执行迁移，再运行 `mix phx.server`。

## 宿主机运行应用

在项目根目录直接运行：

```bash
iex -S mix phx.server
```

`mix ts.setup`、`mix ts.reset` 等一次性任务仍然建议直接在宿主机上执行。

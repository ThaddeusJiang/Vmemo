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
  --env-file .env \
  vmemo:local
```

容器会先在 release 中执行迁移，再运行 `bin/vmemo start`。

## Release 模式远程登录 IEx

当应用以 release 方式运行（`bin/vmemo start`）时，可以通过 release 命令远程连接到正在运行的节点。

先找到容器名：

```bash
docker ps --format '{{.Names}}'
```

然后远程进入 IEx：

```bash
docker exec -it <container_name> /app/bin/vmemo remote
```

连接成功后即可执行 Elixir 代码，例如：

```elixir
Vmemo.Release.migrate()
```

退出远程 IEx 使用 `Ctrl+C` 两次。

## 宿主机运行应用

在项目根目录直接运行：

```bash
iex -S mix phx.server
```

`mix ts.setup`、`mix ts.reset` 等一次性任务仍然建议直接在宿主机上执行。

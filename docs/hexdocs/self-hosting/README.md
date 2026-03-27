# Self-hosting Vmemo

这个目录提供 Vmemo 的 Docker Compose 自托管入口，包含：

- `vmemo`
- `postgres`
- `typesense`
- optional `cloudflared`（preview profile）

## 最简单版本（推荐先跑通）

适合快速启动，直接使用仓库里的 `docker-compose.yml`。

1. 进入目录：

```bash
cd docs/hexdocs/self-hosting
```

2. 复制环境变量模板并填写必要变量：

```bash
cp .env.example .env
```

必填变量：

- `SECRET_KEY_BASE`
- `ADMIN_PASSWORD`
- `DATABASE_URL`
- `TYPESENSE_API_KEY`
- `RESEND_API_KEY`
- `SENTRY_DSN`

3. 启动服务：

```bash
docker compose up -d
```

4. 检查状态和日志：

```bash
docker compose ps
docker compose logs -f vmemo
```

5. 打开：

```text
http://localhost:14000
```

## 最全版本（从零自定义）

适合你要完全控制 `.env` 与 compose 内容，或需要可选公开域名。

### 1) 准备 `.env`

你可以从模板开始：

```bash
cp .env.example .env
```

示例：

```env
PHX_HOST=localhost
PHX_SERVER=true
PORT=4000
SECRET_KEY_BASE=replace_with_a_long_random_secret
ADMIN_PASSWORD=replace_with_a_strong_admin_password
DATABASE_URL=postgres://postgres:postgres@postgres/vmemo
TYPESENSE_URL=http://typesense:8108
TYPESENSE_API_KEY=replace_with_a_strong_typesense_key
RESEND_API_KEY=replace_with_your_resend_api_key
SENTRY_DSN=https://public@example.com/1
SENTRY_ENV=production
OPENROUTER_API_KEY=
MOONDREAM_API_KEY=
MOONDREAM_URL=
TUNNEL_TOKEN=
```

生成 `SECRET_KEY_BASE`：

```bash
openssl rand -hex 64
```

### 2) 准备 compose

可直接复制 example 作为起点：

```bash
cp docker-compose.example.yml docker-compose.yml
```

重点确认 `vmemo` 的 storage volume：

```yaml
services:
  vmemo:
    volumes:
      - ../../../vmemo_data/storage:/app/storage
```

### 3) 启动和验证

```bash
docker compose up -d
docker compose ps
```

访问：

```text
http://localhost:14000
```

容器启动流程（release）：

1. `bin/vmemo eval "Vmemo.Release.migrate()"`
2. `bin/vmemo start`

说明：

- 当前项目统一使用 Ash + ash_postgres。
- `Vmemo.Release.migrate()` 是该项目首选的 release 迁移入口。
- 它会同时执行 AshPostgres repo migrations 与 Typesense migrations。
- 本地迁移建议使用 Ash 任务（如 `mix ash.migrate`），不建议使用 `mix ecto.*`。

远程 IEx：

```bash
docker exec -it <container_name> /app/bin/vmemo remote
```

### 4) 可选：Cloudflare Tunnel 对外暴露

完整配置请参考：

- `docs/hexdocs/self-hosting/cloudflare-tunnel-cli.md`

## Notes

- 默认镜像标签是 `thaddeusjiang/vmemo:latest`；如需固定版本，可在 compose 文件改为具体 tag（例如 `v0.1.0`）。
- compose 依赖容器启动时自动执行数据库迁移和 Typesense 迁移。
- 如需公网访问，请在入口层或反向代理启用 HTTPS。

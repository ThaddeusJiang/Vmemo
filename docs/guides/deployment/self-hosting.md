# Self-hosting Vmemo

这个目录提供 Vmemo 的 Docker Compose 自托管入口，包含：

- `vmemo`
- `postgres`
- `typesense`
- optional `cloudflared`

## 最简单版本（推荐先跑通）

适合快速启动，直接使用 `docs/guides/deployment/self-hosting` 里的样板文件。

1. 进入样板目录：

```bash
cd docs/guides/deployment/self-hosting
```

2. 复制环境变量模板并填写必要变量：

```bash
cp .env.example .env
```

必填变量：

- `SECRET_KEY_BASE`
- `ADMIN_PASSWORD`
- `DATABASE_URL`
- `TYPESENSE_URL`
- `TYPESENSE_API_KEY`
- `MOONDREAM_API_KEY`
- `OPENROUTER_API_KEY`
- `RESEND_API_KEY`
- `SENTRY_DSN`

可选：

- `SENTRY_ENV`
- `MOONDREAM_URL`（默认 `https://api.moondream.ai/v1/`）

如果你在本地运行 moondream，请在 `.env` 设置：

```env
MOONDREAM_URL=http://host.docker.internal:2020/v1/
```

如果你想使用本地刚 build 的镜像，在当前目录运行：

```bash
VMEMO_IMAGE=thaddeusjiang/vmemo:latest docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml up -d
```

3. 启动服务：

```bash
docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml up -d
```

4. 检查状态和日志：

```bash
docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml ps
docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml logs -f vmemo
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
cp docs/guides/deployment/self-hosting/.env.example .env
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
OPENROUTER_API_KEY=replace_with_your_openrouter_key
MOONDREAM_API_KEY=replace_with_your_moondream_key
# Optional, default is https://api.moondream.ai/v1/
MOONDREAM_URL=
```

生成 `SECRET_KEY_BASE`：

```bash
openssl rand -hex 64
```

### 2) 准备 compose

本仓库已提交默认 compose 文件，可直接作为起点并按需编辑：

```bash
${EDITOR:-vi} docs/guides/deployment/self-hosting/docker-compose.yml
```

重点确认 `vmemo` 的 storage volume：

```yaml
services:
  vmemo:
    volumes:
      - ./vmemo_data/storage:/app/storage
```

### 3) 启动和验证

```bash
docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml up -d
docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml ps
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

### 4) 可选：Cloudflare Tunnel 对外暴露（Docker）

1. 在 Cloudflare Zero Trust 创建 remotely-managed tunnel，并拿到 token。
2. 在 `.env` 设置：

```env
CLOUDFLARED_TOKEN=replace_with_your_tunnel_token
PHX_HOST=your.public.hostname
```

3. 启动服务（包含 tunnel）：

```bash
docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml up -d
```

4. 验证：

```bash
docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml ps
curl -I https://your.public.hostname
```

说明：

- 这里使用 `--url` 只会把公网请求转发到 `vmemo`（`http://vmemo:4000`）。
- `postgres` 和 `typesense` 仅供 `vmemo` 容器内部依赖，不会被 cloudflared 直接公开。
- 这个 Docker 方案不依赖 `~/.cloudflared/config.yml` 等 Docker 外部配置文件。

CLI 方式请参考：

- `docs/guides/deployment/cloudflare-tunnel-cli.md`
- CLI 指南同样使用 `--url` 模式，不需要 `~/.cloudflared/config.yml`。

## Notes

- 默认镜像标签是 `thaddeusjiang/vmemo:latest`；如需固定版本，可在 compose 文件改为具体 tag（例如 `v0.1.0`）。
- 你也可以通过环境变量覆盖镜像：`VMEMO_IMAGE=your-image:tag docker compose -f docs/guides/deployment/self-hosting/docker-compose.yml up -d`。
- compose 依赖容器启动时自动执行数据库迁移和 Typesense 迁移。
- 如需公网访问，请在入口层或反向代理启用 HTTPS。

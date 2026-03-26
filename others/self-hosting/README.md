# Self-hosting Vmemo

这个目录提供一个最小的 Docker Compose 自托管入口，用于运行：

- `vmemo`
- `postgres`
- `typesense`

## Quick start

1. 进入当前目录：

```bash
cd others/self-hosting
```

2. 复制环境变量模板：

```bash
cp .env.example .env
```

3. 编辑 `.env`，至少填写这些必需变量：

- `SECRET_KEY_BASE`
- `ADMIN_PASSWORD`
- `DATABASE_URL`
- `TYPESENSE_API_KEY`
- `RESEND_API_KEY`
- `SENTRY_DSN`

建议同时确认这些值：

- `PHX_HOST`
- `TYPESENSE_URL`
- `SENTRY_ENV`
- `OPENROUTER_API_KEY`
- `MOONDREAM_API_KEY`
- `MOONDREAM_URL`

4. 准备 Compose 文件：

```bash
cp docker-compose.example.yml docker-compose.yml
```

5. 启动：

```bash
docker compose up -d
```

如果你不想复制 compose 文件，也可以直接运行：

```bash
docker compose -f docker-compose.example.yml up -d
```

## Required environment variables

当前生产运行配置会直接要求以下变量存在，否则容器启动失败：

- `DATABASE_URL`
- `ADMIN_PASSWORD`
- `SECRET_KEY_BASE`
- `RESEND_API_KEY`
- `SENTRY_DSN`

`typesense` 服务本身还要求：

- `TYPESENSE_API_KEY`

一个可工作的本地 compose 示例：

```env
PHX_HOST=localhost
PHX_SERVER=true
PORT=4000
SECRET_KEY_BASE=replace_with_a_long_random_secret
ADMIN_PASSWORD=replace_with_a_strong_admin_password
DATABASE_URL=ecto://postgres:postgres@postgres/vmemo
TYPESENSE_URL=http://typesense:8108
TYPESENSE_API_KEY=replace_with_a_strong_typesense_key
RESEND_API_KEY=replace_with_your_resend_api_key
SENTRY_DSN=https://public@example.com/1
SENTRY_ENV=production
```

`OPENROUTER_API_KEY` 和 `MOONDREAM_API_KEY` 只有在你要启用对应 AI 能力时才需要填写。

## Ports and volumes

默认端口映射：

- Vmemo: `14000 -> 4000`
- PostgreSQL: `54321 -> 5432`
- Typesense: `8766 -> 8108`

默认数据目录：

- PostgreSQL: `./vmemo_data/pg-data`
- Typesense: `./vmemo_data/ts-data`

## Verify

启动后可以检查服务状态：

```bash
docker compose ps
```

然后访问：

```text
http://localhost:14000
```

如果需要查看应用日志：

```bash
docker compose logs -f vmemo
```

## Notes

- 默认镜像标签是 `thaddeusjiang/vmemo:latest`；如果你要固定版本，请在 [`docker-compose.example.yml`](/Users/amami/git/my-personal-2026/Vmemo/others/self-hosting/docker-compose.example.yml) 里改成具体 tag（例如 `v0.1.0`）。
- 当前 compose 配置会依赖容器内自动执行数据库迁移和 Typesense 迁移。
- 如果你要对外暴露服务，请把 `PHX_HOST` 改成实际域名，并在反向代理或入口层处理 HTTPS。

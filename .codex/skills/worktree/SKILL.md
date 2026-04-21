---
name: "worktree"
description: "Create a Git worktree for Vmemo with environment copy, Docker compose dev/test adjustments, and mandatory container cleanup after verification."
---

# worktree Skill

当用户要求“创建 worktree”时使用此技能。

## Goal

创建一个可独立开发与验证的 worktree，并确保：

- 从当前目录复制 `.env` 到新 worktree（必须用 `cp`）
- 新 worktree 的 `docker-compose.yml` 同时支持 dev/test 容器使用
- 验证结束后及时执行 `docker compose down` 关闭容器

## Required workflow

1. 确认当前目录存在 `.env`；不存在则停止并告知用户。
2. 创建 worktree（按用户给定分支名/路径；未给定时做最小合理假设）。
3. 使用 `cp` 复制 `.env` 到新 worktree。
4. 在新 worktree 中按需调整 `docker-compose.yml`，确保 dev/test 都可独立启动并避免与现有环境冲突。
5. 启动并验证所需容器（只做最小必要验证）。
6. 验证完成后，必须执行 `docker compose down` 清理容器。

## Commands (reference)

### 1) Create worktree

```bash
git worktree add ../<worktree-dir> -b <branch-name>
```

如分支已存在，可改用：

```bash
git worktree add ../<worktree-dir> <existing-branch>
```

### 2) Copy `.env` from current directory (required)

```bash
cp .env ../<worktree-dir>/.env
```

禁止使用符号链接替代此步骤；必须是复制。

### 3) Adjust `docker-compose.yml` for dev/test usage

在新 worktree 中检查并按需修改 `docker-compose.yml`，至少覆盖以下两点：

- dev services: `postgres`, `typesense`
- test services/profile: `postgres-test`, `typesense-test`

建议将端口改为环境变量可配置形式（示例）：

```yaml
services:
  postgres:
    ports:
      - "${DEV_POSTGRES_PORT:-15432}:5432"

  typesense:
    ports:
      - "${DEV_TYPESENSE_PORT:-18108}:8108"

  postgres-test:
    ports:
      - "${TEST_POSTGRES_PORT:-25432}:5432"

  typesense-test:
    ports:
      - "${TEST_TYPESENSE_PORT:-28108}:8108"
```

必要时同步更新新 worktree 的 `.env` 端口变量，避免多 worktree 并行时端口冲突。

### 4) Verify (minimal)

```bash
cd ../<worktree-dir>
docker compose up -d
docker compose --profile test up -d
```

可选检查：

```bash
docker compose ps
```

### 5) Mandatory cleanup

验证结束后立即执行：

```bash
docker compose down
```

若本次启用了 test profile，仍使用同一条 `down` 命令即可回收对应容器与网络。

## Guardrails

- 遵循“最小改动”原则，不做与 worktree 启用无关的重构。
- 不修改 `main`/`develop` 现有行为，除非用户明确要求。
- 若需要改 schema/migration、依赖、路由、认证等高风险项，先征求用户确认。

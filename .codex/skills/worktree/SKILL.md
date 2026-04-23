---
name: "worktree"
description: "Create a Git worktree for Vmemo with .env copy, env-only runtime URL setup, optional Docker port conflict handling, and mandatory container cleanup after verification."
---

# worktree Skill

当用户主动要求“创建/初始化/验证 worktree”时使用此技能。

## Goal

创建一个可独立开发与验证的 worktree，并确保：

- 从当前目录复制 `.env` 到新 worktree（必须用 `cp`）
- 新 worktree 的运行环境变量与当前 runtime 配置一致（`DATABASE_URL` / `TYPESENSE_URL` / `MOONDREAM_URL`）
- 验证结束后及时执行 `docker compose down` 关闭容器

## Required workflow

### Path A: 需要创建新 worktree

1. 在当前目录先执行 `mise trust && mise install`。
2. 确认当前目录存在 `.env`；不存在则停止并告知用户。
3. 创建 worktree（按用户给定分支名/路径；未给定时做最小合理假设）。
4. 使用 `cp` 复制 `.env` 到新 worktree。
5. 在新 worktree 中确认 `.env` 提供 `DATABASE_URL` / `TYPESENSE_URL` / `MOONDREAM_URL`。
6. 在启动容器前检查目标端口是否被占用；若被占用，再按需调整新 worktree 的 `docker-compose.yml` 端口映射，并同步更新 `.env` 对应 URL。
7. 启动所需容器（`docker compose up -d`，必要时再启 test profile）。
8. 在新 worktree 中执行 `mix deps.get`。
9. 在新 worktree 中执行 `mix setup`。
10. 验证完成后，必须执行 `docker compose down` 清理容器。

### Path B: 用户已触发且当前目录已是 worktree

1. 识别当前目录为 Git worktree 后，执行 `mise trust && mise install`。
2. 确认当前 worktree 下存在 `.env`；若缺失则从对应源目录使用 `cp` 补齐，无法确定源目录时停止并告知用户。
3. 在当前 worktree 中确认 `.env` 提供 `DATABASE_URL` / `TYPESENSE_URL` / `MOONDREAM_URL`。
4. 在启动容器前检查目标端口是否被占用；若被占用，再按需调整当前 worktree 的 `docker-compose.yml` 端口映射，并同步更新 `.env` 对应 URL。
5. 启动所需容器（`docker compose up -d`，必要时再启 test profile）。
6. 在当前 worktree 中执行 `mix deps.get`。
7. 在当前 worktree 中执行 `mix setup`。
8. 验证完成后，必须执行 `docker compose down` 清理容器。

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

### 3) Handle port conflicts only when needed

默认优先复用仓库现有 `docker-compose.yml`。仅在端口冲突时，才修改当前 worktree 的端口映射，并同步更新 `.env`：

- dev services: `postgres`, `typesense`
- test services/profile: `postgres-test`, `typesense-test`

### 4) Verify (minimal)

```bash
cd ../<worktree-dir>
mise trust && mise install
# Check required ports before compose up.
# If occupied, update .env URLs first, then continue.
# Example URL fields:
# - DATABASE_URL
# - TYPESENSE_URL
# - MOONDREAM_URL
docker compose up -d
docker compose --profile test up -d
mix deps.get
mix setup
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

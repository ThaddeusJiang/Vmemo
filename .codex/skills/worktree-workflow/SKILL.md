---
name: "worktree-workflow"
description: "在 Vmemo 中创建或校验 Git worktree，自动从 main 复制 .env，执行最小环境/运行时检查，按需处理端口冲突，并在结束后强制清理容器。"
---

# worktree Skill

当用户明确要求“创建 / 初始化 / 验证 worktree”时使用本技能。

## Goal

以最小步骤完成 worktree 准备与验证，不中断、不做无关改动。

## Single source rules

1. `.env` 缺失时：直接从 `main` 复制并继续（必须 `cp`，禁止符号链接）。
2. 端口冲突时必须使用 `docker-compose.override.yml` 覆盖端口映射，禁止修改 `docker-compose.yml`；并同步 `.env` URL。
3. 验证结束后必须执行 `docker compose down`。

## Required vars

目标目录 `.env` 必须包含：
- `DATABASE_URL`
- `TYPESENSE_URL`
- `MOONDREAM_URL`

## Unified flow

1. `mise trust && mise install`
2. 若目标目录缺少 `.env`：
   - 定位本地 `main` 目录
   - `cp <main-dir>/.env <target-dir>/.env`
3. 校验 `.env` 包含 Required vars
4. 若端口冲突：创建/更新 `docker-compose.override.yml` 端口映射并同步 `.env` URL
5. `mix deps.get`
6. 仅在需要运行 dev server 或 `mix test` 时，再执行：
   - `docker compose up -d`（需要时再启 test profile）
   - `mix setup`
7. 若本次启动过容器，验证完成后执行 `docker compose down`

## Path switch (only differences)

### Path A: 创建新 worktree

- 先创建 worktree：
  - `git worktree add ../<worktree-dir> -b <branch-name>`
  - 或 `git worktree add ../<worktree-dir> <existing-branch>`
- 然后对新 worktree 执行 Unified flow。

### Path B: 当前目录已是 worktree

- 直接对当前目录执行 Unified flow。

## Minimal commands

```bash
# create (Path A only)
git worktree add ../<worktree-dir> -b <branch-name>

# verify (both paths, in target worktree)
mise trust && mise install
# Check required ports before compose up.
# If occupied, create/update docker-compose.override.yml and update .env URLs first, then continue.
# Example URL fields:
# - DATABASE_URL
# - TYPESENSE_URL
# - MOONDREAM_URL
mix deps.get

# Only when running dev server or tests:
docker compose up -d
docker compose --profile test up -d
mix setup

# cleanup (mandatory)
docker compose down
```

## Guardrails

- 不修改 `main` 行为，除非用户明确要求。
- 端口冲突处理仅允许在当前 worktree 新增或更新 `docker-compose.override.yml`；禁止改动 `docker-compose.yml`。
- 涉及 schema/migration、依赖、路由、认证等高风险项需先征求确认。

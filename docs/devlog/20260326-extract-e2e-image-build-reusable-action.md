# 2026-03-26 提取 E2E Image Build 为可复用 Action

## 背景

- E2E workflow 之前在单个 `e2e` job 内直接 `docker build`。
- 同一条链路中“构建镜像 + 启动服务 + 跑测试”串行执行，重复运行时耗时偏高。

## 目标

- 把 E2E 的镜像构建提取为可复用 action。
- 在 GitHub Actions 中缓存镜像（保留 7 天）。
- CI 拆阶段：先 build image，再运行 e2e。

## 本次改动

1. 新增可复用 action
- 文件：`.github/actions/build-ci-image/action.yml`
- 功能：
  - 从 `actions/cache` 恢复 image tar（7 天）
  - cache hit 时 `docker load`
  - cache miss 时 `docker build + docker save`
  - 上传 artifact 给后续 job 使用（7 天）
- 输入参数保持最小：
  - `image_name`
  - `cache_key`
  - （可选）`artifact_name`，默认 `vmemo-e2e-image`

2. 重构 E2E workflow
- 文件：`.github/workflows/e2e-tests.yml`
- 新结构：
  - `build-image` job：专门构建并缓存镜像
  - `e2e` job：`needs: build-image`，先下载并加载镜像，再启动 compose 跑测试
- 命名统一：
  - image: `thaddeusjiang/vmemo:e2e`
  - artifact: `vmemo-e2e-image`

3. checkout 版本统一
- `e2e-tests.yml` 中的 `actions/checkout` 统一为 `actions/checkout@v6.0.2`。

## 说明

- `release.yml` 保持原有简单方案（直接 `docker/build-push-action`），不复用该 action。
- 该 action 当前只服务 CI/E2E 场景。

## Follow-up

- Adjusted E2E step order:
  - Move `Start app with compose` earlier (right after loading image).
  - Move `Setup Bun` to after app startup checks (`Wait for app`).
- Added `mix.exs` into image cache key hash inputs to avoid stale image cache when only dependency/build configuration changes in `mix.exs`.
- Fixed E2E compose runtime env mismatch:
  - `e2e-test/docker-compose.yml` passed `ADMIN_TOKEN`, but runtime requires `ADMIN_PASSWORD`.
  - Updated compose env to pass `ADMIN_PASSWORD` so app container can boot in CI.
- Updated E2E workflow database naming in GitHub Actions from `vmemo_dev` to `vmemo`:
  - `POSTGRES_DB`
  - postgres healthcheck database
  - `DATABASE_URL`
- Removed invalid `retention-days` input from `actions/cache@v4` in reusable action
  (keep retention on artifact upload only).
- Added E2E runtime caches in workflow:
  - `e2e-test/node_modules` cache keyed by `e2e-test/bun.lock`
  - `~/.cache/ms-playwright` cache keyed by `e2e-test/bun.lock`
- Split Playwright install step for better cache usage:
  - always run `playwright install-deps chromium` for host deps
  - run `playwright install chromium` only when browser cache misses
- Fixed E2E instability caused by Typesense image embedding model download in prod runtime:
  - added strict runtime env `TYPESENSE_IMAGE_EMBEDDING` (`true|false`)
  - set `TYPESENSE_IMAGE_EMBEDDING=false` in E2E CI workflow and compose env

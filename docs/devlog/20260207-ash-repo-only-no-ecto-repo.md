# 完全迁移到 AshRepo，不再使用 Ecto Repo 入口

- **日期**: 2026-02-07
- **目标**: 一切以 Ash 为基础，mix 任务与 Release 均不依赖 `ecto_repos` 与 `mix ecto.*`。

## 修改摘要

1. **mix.exs aliases**
   - `ecto.setup` → `ash.setup`：`ash_postgres.create` + `ash.migrate` + seeds
   - `ecto.reset` → `ash.reset`：`ash_postgres.drop` + `ash.setup`
   - `setup` 现调用 `ash.setup`
   - `test`：`ash_postgres.create --quiet` + `ash.migrate --quiet` + test

2. **lib/vmemo/release.ex**
   - `repos/0` 改为从 `Application.fetch_env!(:vmemo, :ash_domains)` 推导：遍历 domains → resources → `AshPostgres.DataLayer.Info.repo/1` → 去重。
   - 不再读取 `ecto_repos`。

3. **config/config.exs**
   - 移除 `ecto_repos: [Vmemo.AshRepo]`，仅保留 `ash_domains`。

4. **docs/mix_release.md**
   - 回滚说明中的“版本号见 `mix ecto.migrations`”改为“见 `mix ash.migrate --dry-run` 或迁移目录时间戳”。

## 使用方式

- 本地/CI：`mix setup`、`mix ash.reset`、`mix test` 与之前一致，仅底层改为 Ash 任务。
- 迁移：`mix ash.codegen` 生成迁移，`mix ash.migrate` 执行。
- Release 迁移：`bin/migrate` 或 `bin/vmemo eval "Vmemo.Release.migrate()"` 不变，Release 内部从 `ash_domains` 获取 repos。

## 说明

- 底层仍为 Ecto（AshPostgres 基于 Ecto.Repo / Ecto.Migrator），未移除 `ecto_sql` 等依赖。
- 迁移文件仍在 `priv/ash_repo/migrations/`，格式仍为 `use Ecto.Migration`（由 `mix ash_postgres.generate_migrations` 生成）。

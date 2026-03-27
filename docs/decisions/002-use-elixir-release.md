# 使用 Elixir Release 作为 Docker 启动入口

Date: 2026-03-26

Status: accepted

## Context

- 现有 Docker runner 使用 Elixir + Mix 运行（`mix ash.migrate`、`mix ts.migrate`、`mix phx.server`）。
- 项目已明确采用单一 prod Docker 路径，需要一个更稳定、可预测的生产启动入口。
- `release` 启动方式（`bin/vmemo start`）可以统一运行时行为，避免把 Mix 作为线上主进程依赖。

## Decision

**切换回 Elixir Release 启动。**

- 构建阶段执行 `mix release`
- runner 镜像仅拷贝 release 产物
- 容器启动流程改为：
  1. `bin/vmemo eval "Vmemo.Release.migrate()"`
  2. `bin/vmemo start`
- 其中 `Vmemo.Release.migrate()` 统一执行 AshPostgres repo migrations 与 Typesense migrations

## Consequences

- 优点：
  1. 生产启动入口统一为 release，运行时更加收敛。
  2. runner 镜像不再依赖 Mix 作为主运行方式。
  3. compose 与 CI 的 app 启动命令可统一使用 `start`。
- 代价：
  1. 需要维护 release migration 入口（`Vmemo.Release`）。
  2. 线上临时任务不能默认依赖 `mix ...`，应通过 `bin/vmemo eval ...` 执行。

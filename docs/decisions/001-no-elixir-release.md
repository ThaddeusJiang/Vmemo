# 不使用 Elixir Release，Docker 内使用 Mix

Date: 2026-02-08

Status: superseded by [002-use-elixir-release.md](./002-use-elixir-release.md)

## Context

- 生产/预览环境通过 Docker 部署，runner 容器需要决定：用 **Elixir Release**（`mix release` + `bin/vmemo start`）还是 **Elixir 镜像 + Mix**（`mix phx.server`、`mix ash.migrate` 等）。
- Release 的常见好处：镜像可更精简、无 Mix 依赖、单一可执行入口。
- 本项目希望：在容器内能直接使用 Mix 和 IEx 做运维与排查，同时 server 仍以 prod 环境运行。

## Decision

**不使用 Elixir Release。** Runner 容器使用 Elixir 官方镜像，在容器内继续使用 Mix 运行应用（`mix phx.server`、`mix ash.migrate`）和一次性任务（如 `mix ts.reset`），与本地开发体验一致。

原因简要归纳：

1. **运维与排查**：需要在不重建镜像的前提下，用 `mix`、`iex` 在容器里执行任务和调试；Release 环境下没有 Mix，只能通过 `bin/vmemo eval "Module.fun()"`，且需事先把逻辑放进 Release 模块，不如直接保留 Mix 灵活。
2. **简单一致**：同一套命令在本地与 Docker 内一致（prod 用 `MIX_ENV=prod`），减少「本地用 Mix、生产用 Release」两套心智与文档。
3. **成本与收益**：Release 带来的镜像体积与启动方式优化，对本项目当前规模不是刚需；引入 Release 会增加构建步骤、overlay 脚本和「无 Mix」下的任务入口（如迁移、ts_reset）的维护成本，得不偿失。

## Others

- 构建与运行说明见 [build_and_run.md](../build_and_run.md)。
- 若日后部署规模或安全策略要求「容器内不可有 Mix」，再评估引入 Release 或混合方案。

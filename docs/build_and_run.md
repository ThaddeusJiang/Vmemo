# 构建和运行

Docker runner 使用 Elixir 镜像 + Mix，与本地开发一致（`mix phx.server`、`mix ash.migrate`、`mix ts.migrate` 等）。

本地隔离运行入口使用 [`_local/docker-compose.yml`](/Users/amami/git/my-personal-2026/Vmemo/_local/docker-compose.yml)。该文件基于 `docker-compose.example.yml`，并把数据目录、`storage` 和 `.env` 都放到 `_local/` 下，避免污染项目根目录。

## 在 Docker 里执行一次性任务

镜像默认使用 `ENTRYPOINT + CMD` 启动，entrypoint 依次执行 `mix ash.migrate`、`mix ts.migrate`，然后用 `mix phx.server` 启动应用。要执行 `mix ts.setup`、`mix ts.reset` 等一次性任务，用**一次性容器**（不占 4000 端口）：

```bash
# 宿主机、项目根目录
docker compose -f _local/docker-compose.yml run --no-deps vmemo mix ts.reset
```

不要在已跑着 Web 的**同一容器里**跑会启动整应用的任务（如 `mix ts.setup` 或 `mix ts.reset`），避免 4000 端口冲突。

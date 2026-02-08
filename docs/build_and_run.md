# 构建和运行

Docker runner 使用 Elixir 镜像 + Mix，与本地开发一致（`mix phx.server`、`mix ash.migrate` 等）。

## 在 Docker 里执行一次性任务

镜像用 `mix phx.server` 启动。要执行 ts_reset 等一次性任务，用**一次性容器**（不占 4000 端口）：

```bash
# 宿主机、项目根目录
docker compose -f docker-compose.local.yml run --no-deps app mix ts.reset
```

不要在已跑着 Web 的**同一容器里**跑会启动整应用的任务（如 `mix ts.reset`），避免 4000 端口冲突。

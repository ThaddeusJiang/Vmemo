# 开发日志：修复 mix compile 与 docker build 警告

日期：2026-02-05

## 目标
- 收集并逐一列出 `mix compile` 与 `docker build` 的警告
- 逐一修复警告并验证

## 计划
- 运行 `mix compile`，记录警告
- 运行 `docker build`，记录警告
- 逐条定位并修复
- 复跑确认

## 记录
- 开始执行，等待收集警告输出。

## 发现的问题
### mix compile
- 警告：`Oban.Web.Components.Icons` 中 `svg_mini/1` 未使用（来自 `deps/oban_web`）
  - 位置：`deps/oban_web/lib/oban/web/components/icons.ex:16`

### docker build
- 构建在 `mix deps.get --only prod` 失败
  - 报错：`Failed to fetch record ... :timeout`，随后 `Unknown package splode in lockfile`
  - 发生在干净容器环境，Hex registry 拉取超时导致无法解析 lockfile

## 下一步
- 评估 oban_web 警告：是否接受上游警告、打补丁（fork/本地 path），或引入抑制编译选项
- 调整 Dockerfile 以提高 Hex 拉取稳定性（如 `HEX_HTTP_TIMEOUT`/`HEX_HTTP_CONCURRENCY`）并复跑

## 处理结果
- Dockerfile 增加 Hex 拉取稳定性配置：`HEX_HTTP_TIMEOUT=120`、`HEX_HTTP_CONCURRENCY=1`、`HEX_HTTP_RETRIES=3`
- docker build 已成功完成，但仍有依赖警告（见下）

## 仍需处理的警告
- oban_web: `svg_mini/1` 未使用（`lib/oban/web/components/icons.ex:16`）
- ash_json_api: `Plug.Conn` struct 更新的类型警告（`lib/ash_json_api/plug/parser.ex:152`）

## 备注
- 以上两条警告均来自上游依赖，且当前锁定版本已是最新版本。
- 若需要彻底消除，需要对依赖打补丁（本地 vendor 或 fork）。

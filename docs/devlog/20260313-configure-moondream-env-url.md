# 配置 Moondream URL 为环境变量并验证联通

## 背景
- 需要将 Moondream 服务地址统一从环境变量读取。
- 目标服务地址为 `http://m4mini:2020/v1`。

## 变更
- 更新 `config/dev.exs`：`moondream_url` 固定为 `"http://localhost:2020/v1"`（dev 配置不读取环境变量）。
- 保持 `config/runtime.exs` 通过 `MOONDREAM_URL` 覆盖 `moondream_url`（运行时环境变量入口）。
- 更新 `lib/small_sdk/moondream.ex`：
  - SDK 请求路径改为 `/caption`、`/query`、`/point`、`/detect`、`/segment`。
  - 移除 base URL 自动规范化逻辑，改为统一约定配置值必须包含 `/v1`。
- 更新 `AGENTS.md`：
  - 新增 guideline：不要在代码中处理 env 格式兼容；env 不合法时直接报错。

## 验证
- 使用 `mix run` 直接调用 `SmallSdk.Moondream.caption/2` 进行联通测试。

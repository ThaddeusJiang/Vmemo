# 20260128-typesense-reset-no-start

## 总结
- 让 Typesense reset 脚本在不启动 Web 的情况下也能运行。

## 变更
- 在 reset 脚本里手动启动 Telemetry 与 Finch（Req.Finch）。
- 更新注释提示使用 `mix run --no-start`。

## 测试
- 未运行（按需执行：`mix run --no-start priv/ts/reset.exs`）。

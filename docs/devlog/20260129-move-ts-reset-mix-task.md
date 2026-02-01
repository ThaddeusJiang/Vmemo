# 将 ts.reset 移动到 mix task

## 背景
- 需要将 `priv/ts/reset.exs` 迁移为 mix task 统一入口。

## 变更
- 新增 `mix ts.reset` 任务。
- 移除 `priv/ts/reset.exs` 脚本与对应 alias。

## 说明
- `mix setup` 继续使用 `ts.reset` 任务。

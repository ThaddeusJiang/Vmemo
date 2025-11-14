# 修复 Oban 依赖版本冲突

**项目**: Vmemo (Phoenix LiveView + Ash + Oban)
**日期**: 2025-01-28
**标签**: `elixir` `phoenix` `oban` `dependency` `mix`

## 问题

ElixirLS 编译时出现依赖错误：

```
** (Mix.Error) Can't continue due to errors on dependencies
```

## 原因分析

通过 `mix deps.tree` 检查发现版本冲突：
- `oban_web ~> 2.0` 需要 `oban ~> 2.19`
- 但 `mix.exs` 中 `oban` 的版本要求是 `~> 2.17`

虽然 `~> 2.17` 理论上允许 2.19，但 ElixirLS 在依赖检查时可能无法正确解析，导致编译失败。

## 解决方案

1. **更新 Oban 版本要求**
   - 将 `mix.exs` 中的 `{:oban, "~> 2.17"}` 更新为 `{:oban, "~> 2.19"}`
   - 确保与 `oban_web` 的版本要求一致

2. **清理缓存**
   - 删除 `.elixir_ls` 目录（ElixirLS 缓存）
   - 删除 `_build` 目录（构建缓存）

3. **重新获取依赖**
   - 运行 `mix deps.get` 重新获取依赖
   - 运行 `mix compile` 验证编译成功

## 代码变更

```elixir
# mix.exs
- {:oban, "~> 2.17"},
+ {:oban, "~> 2.19"},
```

## 验证结果

- ✅ 依赖获取成功
- ✅ 编译成功（69 个文件）
- ✅ 无 linter 错误
- ✅ `mix deps.loadpaths` 执行成功

## 经验总结

1. 当依赖出现版本冲突时，优先检查依赖树（`mix deps.tree`）找出具体冲突
2. ElixirLS 缓存可能导致依赖检查失败，清理 `.elixir_ls` 目录可以解决
3. 确保直接依赖的版本要求与间接依赖的要求一致，避免版本范围冲突

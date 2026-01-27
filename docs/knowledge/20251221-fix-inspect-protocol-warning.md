# 修复 Elixir Inspect Protocol 警告

## 问题

在开发环境中使用 `recompile` 时出现警告：

```
warning: the Inspect protocol has already been consolidated, an implementation for Vmemo.Chat.Message has no effect.
```

## 原因

- Ash 框架会自动为资源（Resource）实现 `Inspect` protocol
- Protocol 在编译时被合并（consolidated）以优化性能
- 在开发环境中使用 `recompile` 时，Elixir 试图再次实现已合并的 protocol，导致警告

## 解决方案

在 `mix.exs` 的 `project` 函数中添加配置：

```elixir
consolidate_protocols: Mix.env() == :prod
```

这样协议合并只在生产环境进行，开发环境可以动态添加协议实现而不会出现警告。

## 实施

修改文件：`mix.exs`

```elixir
def project do
  [
    app: :vmemo,
    version: "0.1.0",
    elixir: "~> 1.19",
    elixirc_paths: elixirc_paths(Mix.env()),
    start_permanent: Mix.env() == :prod,
    consolidate_protocols: Mix.env() == :prod,  # 新增
    aliases: aliases(),
    deps: deps(),
    compilers: Mix.compilers() ++ [],
    listeners: [Phoenix.CodeReloader]
  ]
end
```

## 效果

- 开发环境：协议不合并，可以动态添加实现，无警告
- 生产环境：协议合并，性能优化

## 相关技术栈

- **项目**: Vmemo
- **框架**: Phoenix LiveView + Ash
- **语言**: Elixir
- **问题类型**: 开发环境配置优化

## 参考

- Elixir Protocol 文档：https://hexdocs.pm/elixir/Protocol.html#module-consolidation
- Ash Resource 会自动实现 Inspect protocol

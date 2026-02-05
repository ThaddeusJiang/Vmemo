# Tidewave 配置

本文档记录在 Vmemo 中启用 Tidewave 的步骤与注意事项。

## 安装

1. 在 `mix.exs` 添加依赖：

```elixir
def deps do
  [
    {:tidewave, "~> 0.5", only: :dev}
  ]
end
```

2. 在 `lib/vmemo_web/endpoint.ex` 中，放在 `if code_reloading? do` 之前：

```elixir
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave
end

if code_reloading? do
  ...
end
```

3. 在 `config/dev.exs` 打开 LiveView 调试标记（Phoenix v1.8+ 默认已开启）：

```elixir
config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true
```

## MCP 端点

Tidewave MCP 默认在同一端口提供服务，例如 `http://localhost:4000/tidewave/mcp`。将该地址配置到编辑器或 AI 工具中。

## 远程访问与来源限制

默认只允许 localhost 访问。如果在 Docker 或远程环境开发，需要显式允许：

```elixir
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave,
    allow_remote_access: true,
    allowed_origins: ["http://company.local"]
end
```

## 多 Host/子域名开发

如果使用多个 host 或子域名，建议使用 `*.localhost`，并在 `@session_options` 定义后添加：

```elixir
@session_options [
  # ...
]

if code_reloading? do
  @session_options Keyword.merge(@session_options, same_site: "None", secure: true)
end
```

## 内容安全策略（CSP）

若启用了 CSP，Tidewave 会自动在 `script-src` 中启用 `unsafe-eval`，并禁用 `frame-ancestors`。

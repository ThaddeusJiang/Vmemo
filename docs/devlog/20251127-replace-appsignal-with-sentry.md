# 移除 AppSignal 改用 Sentry 监控日志

## 背景

原项目使用 AppSignal 进行错误监控，现改为 Sentry。

## 变更内容

### 1. 移除 AppSignal

- 删除 `config/appsignal.exs` 配置文件
- 从 `mix.exs` 移除 `{:appsignal_phoenix, "~> 2.0"}`
- 移除 `config/dev.exs` 和 `config/prod.exs` 中的 `appsignal` 配置
- 移除 `config/config.exs` 中的 `import_config "appsignal.exs"`

### 2. 添加 Sentry

**依赖 (mix.exs):**
```elixir
{:sentry, "~> 10.2.0"},
{:hackney, "~> 1.21"}
```

**配置 (config/runtime.exs):**
```elixir
config :sentry,
  dsn: sentry_dsn,
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]
```

**Endpoint 集成 (lib/vmemo_web/endpoint.ex):**
- 添加 `use Sentry.PlugCapture` 捕获 Plug 错误
- 添加 `plug Sentry.PlugContext` 收集请求上下文（放在 Router 之前）

**Logger Handler (lib/vmemo/application.ex):**
```elixir
:logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{
  config: %{metadata: [:file, :line]}
})
```

## 部署注意事项

DSN 通过环境变量注入，生产环境需要设置 `SENTRY_DSN`。

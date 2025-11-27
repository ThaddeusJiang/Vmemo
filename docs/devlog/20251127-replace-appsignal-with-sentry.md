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

**配置 (config/prod.exs):**
```elixir
config :sentry,
  dsn: "https://2c7940391427df715386b12696ce2b5e@o350425.ingest.us.sentry.io/4510435930734592",
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]
```

**Endpoint 集成 (lib/vmemo_web/endpoint.ex):**
- 添加 `use Sentry.PlugCapture` 捕获 Plug 错误
- 添加 `plug Sentry.PlugContext` 收集请求上下文（放在 Router 之后）

**Logger Handler (lib/vmemo/application.ex):**
```elixir
:logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{
  config: %{metadata: [:file, :line]}
})
```

## 部署注意事项

DSN 已硬编码在 `config/prod.exs` 中。未来可考虑改为从环境变量读取以提高安全性。

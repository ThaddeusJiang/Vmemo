# 2026-01-28 Zeabur template variables

## 目标
- 学习 Zeabur template-in-code 文档，确认 spec variables 的用法
- 将生产必须的环境变量改为通过 spec variables 提示填写

## 变更
- 在模板 variables 中新增 SENTRY_DSN、RESEND_API_KEY、OPENROUTER_API_KEY、MOONDREAM_URL
- Vmemo 服务对这些变量使用变量默认值，并保留 Admin Token 自动生成
- 移除 Vmemo 中对 TYPESENSE_API_KEY 的 env 默认值，避免覆盖 expose 变量
- standalone 模板新增 TYPESENSE_API_KEY 变量，并在 Vmemo 环境变量中使用
- standalone 模板新增 DATABASE_URL 与 TYPESENSE_URL 变量，并在 Vmemo 环境变量中使用
- standalone 模板移除 postgresql 与 typesense 服务
- standalone 模板改为由用户填写 ADMIN_TOKEN 与 SECRET_KEY_BASE
- standalone 模板补充变量描述示例格式
- standalone 模板补充 ADMIN_TOKEN 与 SECRET_KEY_BASE 示例说明

## 备注
- 生产环境必需变量依据 config/runtime.exs 中的强制读取逻辑

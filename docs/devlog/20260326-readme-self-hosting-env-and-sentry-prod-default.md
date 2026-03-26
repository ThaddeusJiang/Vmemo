# 完善自托管环境变量说明并固定 Sentry 生产默认环境

## 背景

- README 的自托管示例缺少一组最小可运行环境变量说明
- `docker-compose` 示例里关键变量没有在服务段明确展示
- Sentry 在未设置 `SENTRY_ENV` 时回退到 `PHX_HOST`，语义不稳定

## 变更

- 在 README 顶部补充仓库、最近提交、License、Docker Pulls 徽章
- 重写 `.env` 最小示例，明确 `PHX_HOST`、`PHX_SERVER`、`SECRET_KEY_BASE`、`ADMIN_PASSWORD` 等必填项，并保留可选 AI 配置
- 在 `docker-compose` 示例中显式列出关键 `environment` 字段，并通过 shell 参数检查强制要求必要变量
- 在 `config/runtime.exs` 中将 Sentry `environment_name` 的缺省值固定为 `"prod"`
- 修正 `.gitignore` 末尾换行以保持文件格式一致

## 结果

- 自托管用户可以更快拿到可运行的最小配置
- 关键变量缺失时失败路径更明确，减少隐式配置问题
- Sentry 环境命名更稳定，不再依赖 `PHX_HOST`

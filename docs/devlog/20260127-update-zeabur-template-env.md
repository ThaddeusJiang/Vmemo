# 20260127 update zeabur template env

## Summary
- 补齐 Zeabur 模板中的必需环境变量配置。

## Details
- 在 `others/zeabur/vmemo.yml` 中新增 `ADMIN_TOKEN` 与 `SENTRY_DSN`。

## Notes
- 入口脚本会在缺失必需环境变量时直接退出。

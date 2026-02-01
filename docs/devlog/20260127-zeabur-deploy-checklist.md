# 20260127 zeabur deploy checklist

## Summary
- 整理 Zeabur 部署清单，覆盖构建方式、环境变量、依赖服务与发布验证。

## Details
- 新增 `docs/development/zeabur-deploy-checklist.md`。
- 清单基于当前 Docker 入口脚本与 `config/runtime.exs` 的必需配置。

## Notes
- 入口脚本会在缺失必需环境变量时直接退出。

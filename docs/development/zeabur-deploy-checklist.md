# Zeabur Deploy Checklist

以下清单适用于 Vmemo 在 Zeabur 的部署与发布。

## 1. 代码与分支

- [ ] 确认目标分支（通常为 `main`）已包含所需变更
- [ ] 确认 `mix.exs` 与 `mix.lock` 已同步
- [ ] 确认没有未提交的关键变更（尤其是运行时配置相关）

## 2. 构建与运行方式

- [ ] Zeabur 使用项目内 `Dockerfile` 构建
- [ ] 入口脚本为 `docker/entrypoint.sh`
- [ ] 确认 `assets.deploy` 会在镜像构建阶段执行
- [ ] 确认 `PHX_SERVER=true`（入口脚本默认设置）

## 3. 运行时必需环境变量

必须全部设置，否则入口脚本会直接退出：

- [ ] `DATABASE_URL`
- [ ] `SECRET_KEY_BASE`
- [ ] `ADMIN_TOKEN`
- [ ] `SENTRY_DSN`
- [ ] `RESEND_API_KEY`
- [ ] `TYPESENSE_URL`
- [ ] `TYPESENSE_API_KEY`
- [ ] `MOONDREAM_URL`

可选（未设置只会告警）：

- [ ] `OPENROUTER_API_KEY`

## 4. Phoenix 运行配置

- [ ] `PHX_HOST` 设置为实际域名（例如 `vmemo.app`）
- [ ] `PORT` 由 Zeabur 注入或显式设置（默认 4000）
- [ ] 如需 IPv6，设置 `ECTO_IPV6=true`

## 5. 依赖服务检查

- [ ] PostgreSQL 可连通（对应 `DATABASE_URL`）
- [ ] Typesense 可连通（对应 `TYPESENSE_URL`/`TYPESENSE_API_KEY`）
- [ ] Moondream 可连通（对应 `MOONDREAM_URL`）
- [ ] Resend API Key 可用（邮件发送）
- [ ] Sentry DSN 可用（错误上报）

## 6. Zeabur 服务设置

- [ ] 服务端口为 `PORT` 对应值
- [ ] 健康检查指向应用端口（HTTP 访问应返回 200/302）
- [ ] 日志可见 `Starting Vmemo` 与 `PORT=... PHX_HOST=...`

## 7. 发布后验证

- [ ] 首页可访问并正常加载
- [ ] 登录流程正常
- [ ] 上传图片流程正常
- [ ] Typesense 搜索可用（至少能返回新建数据）
- [ ] 任务队列可运行（Oban jobs 无持续失败）
- [ ] Sentry 有收到事件（可用一次手动触发验证）

## 8. 回滚准备

- [ ] 已记录上一版本镜像/部署版本
- [ ] 如有数据库变更，确认可以回滚或有对应修复方案

# 开发日志：Docker 多架构 CI

日期：2026-01-26

## 目标
- 让 Docker Hub 镜像同时支持 `linux/amd64` 与 `linux/arm64`
- 修复 Apple Silicon 拉取 `develop` 镜像失败的问题

## 变更
- CI 增加 QEMU 支持
- Buildx 构建改为多架构 `linux/amd64,linux/arm64`
- 更新 Docker Actions 版本到 v3/v5

## 使用方式
- 触发条件保持不变：`develop`、`main` 分支或 tag push 即会自动发布镜像

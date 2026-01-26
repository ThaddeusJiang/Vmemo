---
title: Docker multi-arch tags in GitHub Actions
date: 2026-01-26
---

今天调整 Docker 发布流程，目标是“单一 tag + 多架构清单”，让同一个 tag 显示多个 OS/ARCH。

变更要点：
- 保持单一 tag（如 `develop` / `v1`）
- 使用 buildx 多平台构建（`linux/amd64,linux/arm64`）并直接推送多架构清单
- main 分支额外发布 `latest` 的多架构清单

这样在 Docker Hub 上同一 tag 下会显示多个 OS/ARCH 条目。

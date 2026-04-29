# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses Calendar Versioning for releases.

## [Unreleased]

### End Users

#### Added
- 登录后页面已支持中/英/日三语切换。
- 新增全局 AI Drawer，可在任意页面快速打开会话入口。
- 图片 caption 与 query 流程已统一到 OpenRouter 调用链，后续能力扩展更一致。
- 统一浅色语义组件（Alert/Badge/Toast），跨页面提示样式更一致。
- 新增用户档案信息（名称、头像、语言、外观）独立存储能力。
- 通知下拉已抽离为可复用组件，交互一致性更好。

#### Fixed
- landing/auth/app 视觉与交互细节对齐，修复多处样式不一致问题。

### Maintainers

- Change: dev/test 的运行时 URL 配置统一收敛到 `config/runtime.exs`。
  Migration:
  1. 在运行环境中补齐并校验以下变量。
  2. 重启服务并确认启动检查通过。
  Example:

```bash
DATABASE_URL=<value>
TYPESENSE_URL=<value>
MOONDREAM_URL=<value>
```

#### Changed
- worktree 开发流程规范收敛：仅在明确需要时触发，并统一创建/清理步骤。

## [Vmemo - 2026.4.19] - 2026-04-19

### End Users

#### Added
- 新增会话内已上传图片回显，上传后可立即看到当前会话资源。
- 引入用户级导入/导出与批量恢复能力，提升数据迁移与备份可用性。
- 后台任务队列按业务拆分（会话、同步、视觉、导入），异步处理稳定性提升。
- 管理端导入流程支持流式上传与大文件处理优化。

#### Fixed
- 修复图片/笔记删除时的关联约束问题。
- 修复找回密码邮箱匹配、聊天图片渲染与多处 CI/格式校验问题。
- 将 Moondream 默认超时调高到 2 分钟，降低慢请求失败率。

### Maintainers

- Change: 发布与测试流程中的环境变量约束统一，运行时依赖显式化。
  Migration:
  1. 校验发布/部署环境中的关键变量是否已配置。
  2. 重新部署后执行启动与基础功能验收。
  Example:

```bash
DATABASE_URL=<value>
TYPESENSE_URL=<value>
MOONDREAM_URL=<value>
ADMIN_PASSWORD=<value>
```

#### Changed
- release 工作流从“脚本拼接”调整为更明确的发布门禁与职责拆分。
- Docker 多架构发布流程调整为分架构构建后合并，发布可观察性更好。
- Docker 自托管接入 Moondream sidecar 转发方案，部署链路更清晰。
- 增加外部服务监控与多平台镜像发布能力。
- Typesense 相关目录与迁移策略收敛，减少运行时隐式行为。

#### Fixed
- 修复 Docker 发布流程中 checkout、digest 合并等关键稳定性问题。

## [Vmemo - 2024.12.25] - 2024-12-25

### End Users

#### Added
- 首版发布：图片上传、基础检索、笔记能力与初始界面。

#### Fixed
- 修复早期 UI 与 Docker 安装流程中的关键问题。

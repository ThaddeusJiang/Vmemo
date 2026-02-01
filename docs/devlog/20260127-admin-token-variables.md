# ADMIN_TOKEN 改为仅通过 Zeabur Variables 输入

## 变更
- 移除 Zeabur 配置中 `ADMIN_TOKEN` 的默认值，强制通过 Variables 手动输入

## 原因
- 默认值会导致部署环境误用占位值，且不利于安全管理

## 影响
- 部署时必须在 Zeabur Variables 中显式设置 `ADMIN_TOKEN`

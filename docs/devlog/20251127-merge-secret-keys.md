# 2025-11-27 合并 SECRET_KEY_BASE 和 JWT_SIGNING_SECRET

## 变更概述

将 `JWT_SIGNING_SECRET` 合并到 `SECRET_KEY_BASE`，简化配置管理并修复硬编码密钥的安全问题。

## 变更内容

### 代码变更

1. **`lib/vmemo/account/ash_user.ex`**
   - 将硬编码的 `signing_secret` 改为从应用配置读取
   - 使用函数形式动态获取 `SECRET_KEY_BASE`

2. **`config/runtime.exs`**
   - 添加应用配置 `:secret_key_base`，供 JWT 签名使用

3. **`config/dev.exs` 和 `config/test.exs`**
   - 添加应用配置 `:secret_key_base`

### 文档变更

- `README.md`: 移除 `JWT_SIGNING_SECRET` 相关说明
- `docs/MIGRATION-GUIDE.md`: 更新环境变量配置说明
- `docs/RELEASE-NOTES.md`: 更新环境变量变更说明
- `docs/TEST-PLAN.md`: 移除测试配置中的 `JWT_SIGNING_SECRET`
- `docs/CODE-REVIEW.md`: 标记硬编码密钥问题已修复

## 影响

### 优势

- ✅ 简化配置：只需管理一个密钥环境变量
- ✅ 修复安全问题：移除了硬编码的密钥
- ✅ 向后兼容：现有功能不受影响

### 注意事项

- ⚠️ 修改 `SECRET_KEY_BASE` 会导致所有 Web 会话和 JWT token 失效
- ⚠️ 生产环境必须设置 `SECRET_KEY_BASE` 环境变量

## 迁移指南

对于现有部署：

1. 确保已设置 `SECRET_KEY_BASE` 环境变量
2. 可以移除 `JWT_SIGNING_SECRET` 环境变量（如果存在）
3. 重启应用

## 相关任务

- [任务文档](tasks/todo/2025-11-27-analyze-secret-key-merge.md)

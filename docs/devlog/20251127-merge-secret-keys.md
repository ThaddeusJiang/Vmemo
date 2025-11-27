# 2025-11-27 合并 SECRET_KEY_BASE 和 JWT_SIGNING_SECRET

## 变更概述

将 `JWT_SIGNING_SECRET` 合并到 `SECRET_KEY_BASE`，简化配置管理并修复硬编码密钥的安全问题。

## 背景分析

### 问题发现

- `SECRET_KEY_BASE`: 用于 Phoenix 框架的加密和签名（cookies、会话等）
- `JWT_SIGNING_SECRET`: 用于 JWT token 的签名，**目前硬编码在代码中**（安全风险）
- 开发环境中两者已使用相同值，证明技术上可行

### 技术可行性分析

**密钥用途对比**:

| 密钥 | 用途 | 使用位置 | 生成方式 |
|------|------|----------|----------|
| `SECRET_KEY_BASE` | Phoenix cookies/会话签名加密 | `VmemoWeb.Endpoint` | `mix phx.gen.secret` |
| `JWT_SIGNING_SECRET` | JWT token 签名 | `AshAuthentication` | `openssl rand -base64 32` |

**技术要求**:
- 类型：两者都是字符串类型
- 长度：都要求足够长（通常 64+ 字符）
- 随机性：都需要强随机性
- 格式：都接受 base64 编码的字符串

### 决策分析

**合并的优势**:
- ✅ 简化配置管理，减少环境变量数量
- ✅ 降低配置错误的可能性
- ✅ 开发环境已经使用相同值，证明技术上可行
- ✅ 对于小型项目，安全性影响可接受

**合并的风险**:
- ⚠️ 密钥轮换影响范围大：修改密钥会导致所有 Web 会话和 JWT token 失效
- ⚠️ 安全边界模糊：一个密钥泄露会影响所有功能
- ⚠️ 不符合"最小权限原则"：不同功能共享密钥

**决策**: 虽然分离密钥更符合安全最佳实践，但考虑到项目规模和简化配置的需求，**选择合并方案**。

## 变更内容

### 代码变更

1. **`lib/vmemo/account/ash_user.ex`**
   - 将硬编码的 `signing_secret` 改为从应用配置读取
   - 提取为私有函数 `get_signing_secret/2`，简化代码
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

- ✅ **简化配置**：只需管理一个密钥环境变量
- ✅ **修复安全问题**：移除了硬编码的密钥
- ✅ **向后兼容**：现有功能不受影响
- ✅ **代码简化**：提取私有函数，代码更清晰

### 注意事项

- ⚠️ 修改 `SECRET_KEY_BASE` 会导致所有 Web 会话和 JWT token 失效
- ⚠️ 生产环境必须设置 `SECRET_KEY_BASE` 环境变量
- ⚠️ 密钥轮换影响范围大，需要谨慎操作

## 迁移指南

对于现有部署：

1. 确保已设置 `SECRET_KEY_BASE` 环境变量
2. 可以移除 `JWT_SIGNING_SECRET` 环境变量（如果存在）
3. 重启应用

## 验证

- ✅ 代码通过 linter 检查
- ✅ 所有环境（dev/test/prod）配置已更新
- ✅ 功能测试通过

## 相关任务

- [任务文档](tasks/todo/2025-11-27-analyze-secret-key-merge.md)

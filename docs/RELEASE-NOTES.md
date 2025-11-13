# Release Notes - API Tokens & Public API

**版本**: v1.0.0
**发布日期**: 2025-01-26
**类型**: 主要功能更新

## 概述

本次发布引入了 API Token 管理系统和 Public API，使 Vmemo 能够与外部应用程序集成。同时完成了从自定义认证系统到 Ash Authentication 的迁移，为未来的功能扩展奠定了基础。

## 新增功能

### 1. API Token 管理系统

完整的 API Token CRUD 功能，支持通过 Web 界面管理 API 访问凭证。

**主要特性**:
- ✅ 创建 API Token（支持设置名称、描述、过期时间）
- ✅ 查看 Token 列表（显示状态、最后使用时间等）
- ✅ 启用/禁用 Token
- ✅ 删除 Token
- ✅ Token 只显示一次的安全机制
- ✅ 自动记录最后使用时间
- ✅ 过期时间管理

**访问路径**: `/tokens`

**安全特性**:
- Token 使用 SHA256 哈希存储，原始 Token 不保存
- Token 前缀 `vmemo_` 便于识别和防止泄露
- 支持手动禁用和自动过期
- 每次使用更新最后使用时间，便于审计

### 2. Public API (v1)

RESTful API 端点，支持外部应用程序访问 Vmemo 功能。

**端点**:
- `POST /api/v1/photos` - 上传照片
- `GET /api/v1/photos/:id` - 获取照片信息
- `DELETE /api/v1/photos/:id` - 删除照片

**认证方式**: Bearer Token

**请求示例**:
```bash
curl -X POST https://your-domain.com/api/v1/photos \
  -H "Authorization: Bearer vmemo_your_token" \
  -F "file=@image.jpg" \
  -F "note=My photo"
```

**响应格式**:
```json
{
  "status": "success",
  "data": {
    "id": "photo-uuid",
    "url": "/storage/v1/<user_id>/photos/filename.jpg",
    "note": "My photo",
    "inserted_at": "2025-01-26T10:30:00Z"
  }
}
```

**文件限制**:
- 支持格式: PNG, JPG, JPEG, GIF, WEBP
- 建议大小: 不超过 10MB

### 3. Ash Authentication 迁移

从自定义的 User/UserToken 系统迁移到 Ash Framework 的认证系统。

**变更内容**:
- 新增 `ash_users` 表（使用 UUID 字符串作为主键）
- 新增 `ash_user_tokens` 表（用于 Ash Authentication）
- 保留 `account_users` 表用于向后兼容
- 数据迁移脚本自动迁移现有用户数据

**优势**:
- 标准化的认证流程
- 更好的扩展性
- 与 Ash Framework 生态系统集成

### 4. Token 管理 UI

基于 Phoenix LiveView 的现代化 Token 管理界面。

**功能**:
- 实时状态更新
- 响应式设计（支持移动端）
- 直观的操作按钮
- Token 创建后的安全提示
- 过期状态可视化

**技术栈**:
- Phoenix LiveView
- Tailwind CSS
- DaisyUI 组件

## 改进

### 安全性改进

1. **Token 哈希存储**: 只存储 SHA256 哈希，不保存原始 Token
2. **Token 前缀**: 使用 `vmemo_` 前缀便于识别
3. **过期管理**: 支持设置 Token 过期时间
4. **状态控制**: 支持手动启用/禁用 Token
5. **审计日志**: 记录 Token 最后使用时间

### 用户体验改进

1. **一次性显示**: Token 创建后只显示一次，提高安全意识
2. **清晰的状态**: 活跃/禁用/过期状态一目了然
3. **描述性命名**: 支持为 Token 添加名称和描述
4. **最后使用时间**: 便于识别活跃的 Token

### 开发者体验改进

1. **RESTful API**: 标准的 REST 接口，易于集成
2. **清晰的错误信息**: 详细的错误码和消息
3. **完整的文档**: API 文档、Token 管理指南、迁移指南
4. **代码示例**: Python, Node.js, cURL 等多种语言示例

## 技术变更

### 新增依赖

无新增外部依赖。使用现有的 Ash Framework 和 Phoenix 生态系统。

### 数据库变更

**新增表**:
- `ash_users` - Ash 用户表
- `ash_user_tokens` - Ash 认证 Token 表
- `api_tokens` - API Token 表

**迁移脚本**:
1. `20251025135540_create_tokens.exs` - 创建 api_tokens 表
2. `20251026000000_migrate_account_users_to_ash_users.exs` - 迁移用户数据
3. `20251026010000_change_uuid_to_string.exs` - UUID 转 String 类型

### API 路由变更

**新增路由**:
```elixir
# Public API
scope "/api/v1", VmemoWeb.Api.V1 do
  pipe_through [:api, :api_auth]

  post "/photos", PhotoController, :create
  get "/photos/:id", PhotoController, :show
  delete "/photos/:id", PhotoController, :delete
end

# Token 管理 UI
scope "/", VmemoWeb do
  pipe_through [:browser, :require_authenticated_user]

  live "/tokens", TokenLive.Index
  live "/tokens/new", TokenLive.New
end
```

### 配置变更

**新增环境变量**:
```bash
# JWT 签名密钥（重要：生产环境必须设置）
JWT_SIGNING_SECRET=your_jwt_secret
```

**可选配置**:
```elixir
# config/runtime.exs
config :vmemo,
  max_file_size: 10 * 1024 * 1024,  # 10MB
  allowed_file_types: ~w(.png .jpg .jpeg .gif .webp)
```

## 破坏性变更

### ⚠️ 需要注意的变更

1. **新增环境变量**: 生产环境必须设置 `JWT_SIGNING_SECRET`
2. **数据库迁移**: 需要运行迁移脚本
3. **用户 ID 类型**: 从 integer 迁移到 string (UUID)

### 向后兼容性

- ✅ 现有用户数据自动迁移
- ✅ 现有功能不受影响
- ✅ 保留 `account_users` 表用于兼容
- ✅ Web UI 登录流程不变

## 已知问题

### P0 - 关键问题（建议尽快修复）

1. **ApiToken 的 user_id/ash_user_id 冲突**
   - 同时存在 integer 和 string 类型的用户 ID 字段
   - 可能导致数据一致性问题
   - 建议: 统一使用 ash_user_id

2. **verify_token 未检查过期时间**
   - Ash 层面缺少过期时间检查
   - 虽然 Service 层有检查，但缺少深度防御
   - 建议: 在 Ash 动作中添加过期检查

3. **AshUser 中硬编码的 signing_secret**
   - JWT 签名密钥硬编码在代码中
   - 生产环境安全风险
   - 建议: 改为从环境变量读取

4. **ApiTokenService 中的 actor 使用不当**
   - 传递 api_token 而不是用户作为 actor
   - 可能导致权限问题
   - 建议: 传递拥有 token 的用户

### P1 - 重要问题（建议修复）

1. **PhotoController 缺少文件大小限制**
   - 可能被大文件攻击
   - 建议: 添加文件大小检查

2. **API 响应码不够细化**
   - 大多数错误返回 400
   - 建议: 使用 415/413/422 等更具体的状态码

### P2 - 改进建议（可选）

1. **缺少速率限制**: 建议添加 API 速率限制
2. **缺少 CORS 配置**: 如需浏览器跨域调用需配置
3. **日志安全性**: 审查日志避免泄露敏感信息

详细问题列表请参考 [Code Review](CODE-REVIEW.md)。

## 升级指南

### 前置条件

- Elixir 1.19+
- PostgreSQL 16+
- 现有 Vmemo 实例

### 升级步骤

1. **备份数据库**
   ```bash
   pg_dump vmemo_prod > backup_$(date +%Y%m%d).sql
   ```

2. **拉取最新代码**
   ```bash
   git checkout main
   git pull origin main
   ```

3. **安装依赖**
   ```bash
   mix deps.get
   ```

4. **设置环境变量**
   ```bash
   # 生成随机密钥
   export JWT_SIGNING_SECRET=$(openssl rand -base64 32)

   # 添加到生产环境配置
   echo "JWT_SIGNING_SECRET=$JWT_SIGNING_SECRET" >> .env
   ```

5. **运行数据库迁移**
   ```bash
   mix ecto.migrate
   ```

6. **验证迁移**
   ```bash
   # 检查新表是否创建
   psql vmemo_prod -c "\dt ash_users"
   psql vmemo_prod -c "\dt api_tokens"

   # 检查数据是否迁移
   psql vmemo_prod -c "SELECT COUNT(*) FROM ash_users"
   ```

7. **重启应用**
   ```bash
   # 如果使用 systemd
   sudo systemctl restart vmemo

   # 如果使用 Docker
   docker-compose restart
   ```

8. **验证功能**
   - 登录 Web 应用
   - 访问 `/tokens` 页面
   - 创建测试 Token
   - 使用 Token 调用 API

### 回滚步骤

如果升级出现问题：

1. **停止应用**
   ```bash
   sudo systemctl stop vmemo
   ```

2. **回滚数据库**
   ```bash
   mix ecto.rollback --step 3
   ```

3. **恢复代码**
   ```bash
   git checkout <previous-version>
   ```

4. **重启应用**
   ```bash
   sudo systemctl start vmemo
   ```

详细迁移指南请参考 [Migration Guide](MIGRATION-GUIDE.md)。

## 测试

### 测试覆盖

- ✅ API 认证测试: 11/11 通过
- ✅ Photo Controller 测试: 完整覆盖
- ✅ Token Service 测试: 核心功能覆盖
- ✅ 迁移测试: 数据完整性验证

### 运行测试

```bash
# 运行所有测试
mix test

# 运行 API 测试
mix test test/vmemo_web/api/

# 运行特定测试
mix test test/vmemo_web/api/auth_test.exs
```

详细测试计划请参考 [Test Plan](TEST-PLAN.md)。

## 文档

### 新增文档

- [Public API 文档](public-api.md) - 完整的 API 参考
- [API Token 管理指南](api-tokens.md) - Token 管理最佳实践
- [Migration Guide](MIGRATION-GUIDE.md) - 详细的迁移步骤
- [Test Plan](TEST-PLAN.md) - 测试计划和用例
- [Code Review](CODE-REVIEW.md) - 代码审查报告

### 更新文档

- [README.md](../README.md) - 添加 Public API 快速开始指南

## 性能影响

### 预期影响

- **API 响应时间**: < 100ms (不含文件上传时间)
- **Token 验证**: < 10ms
- **数据库查询**: 新增索引优化查询性能
- **内存占用**: 增加约 50MB (LiveView 连接)

### 性能优化

- Token 哈希使用索引加速查询
- 异步更新最后使用时间
- Oban 异步处理 Typesense 同步

## 安全考虑

### 安全措施

1. ✅ Token 哈希存储
2. ✅ Token 前缀识别
3. ✅ 过期时间管理
4. ✅ 手动启用/禁用
5. ✅ 文件类型验证
6. ✅ 权限隔离

### 安全建议

1. **生产环境必须设置 JWT_SIGNING_SECRET**
2. **定期轮换 API Token**
3. **为不同应用创建不同 Token**
4. **监控 Token 使用情况**
5. **启用 HTTPS**
6. **考虑添加速率限制**

## 贡献者

- @ThaddeusJiang - 主要开发

## 反馈

如有问题或建议，请：
1. 查看 [GitHub Issues](https://github.com/ThaddeusJiang/Vmemo/issues)
2. 提交新的 Issue
3. 联系技术支持

## 下一步计划

### 短期计划 (1-3 个月)

- [ ] 修复已知的 P0 问题
- [ ] 添加 API 速率限制
- [ ] 改进错误响应码
- [ ] 添加文件大小限制
- [ ] 完善测试覆盖

### 中期计划 (3-6 个月)

- [ ] 支持更多 API 端点（搜索、批量操作等）
- [ ] 添加 Webhook 支持
- [ ] API 版本管理 (v2)
- [ ] 细粒度权限控制
- [ ] API 使用统计和分析

### 长期计划 (6-12 个月)

- [ ] GraphQL API
- [ ] SDK 支持 (Python, Node.js, Go)
- [ ] OAuth 2.0 支持
- [ ] 企业级功能（团队、角色等）

## 致谢

感谢所有测试和反馈的用户！

---

**发布日期**: 2025-01-26
**版本**: v1.0.0
**PR**: [#40](https://github.com/ThaddeusJiang/Vmemo/pull/40)

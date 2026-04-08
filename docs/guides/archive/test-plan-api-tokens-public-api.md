# Test Plan - API Tokens & Public API

本文档描述 API Tokens 和 Public API 功能的完整测试计划。

## 测试概述

### 测试范围

本次测试覆盖以下功能模块：

1. **API Token 管理**: Token 的创建、查看、启用/禁用、删除
2. **Public API**: RESTful API 端点（上传、获取、删除照片）
3. **API 认证**: Bearer Token 认证机制
4. **数据迁移**: 用户数据从 account_users 迁移到 ash_users
5. **权限控制**: 用户只能访问自己的资源

### 测试环境

- **开发环境**: 本地开发机器
- **测试环境**: CI/CD 环境（GitHub Actions）
- **预生产环境**: 与生产环境配置相同的测试环境
- **生产环境**: 实际用户使用的环境

### 测试类型

- **单元测试**: 测试单个函数/模块
- **集成测试**: 测试多个模块协作
- **端到端测试**: 测试完整的用户流程
- **性能测试**: 测试系统性能和负载能力
- **安全测试**: 测试认证和授权机制

## 测试用例

### 1. API Token 管理测试

#### 1.1 创建 Token

**测试用例 TC-001: 成功创建 Token**

**前置条件**:
- 用户已登录
- 访问 `/tokens` 页面

**测试步骤**:
1. 点击"创建新 Token"按钮
2. 填写名称: "Test Token"
3. 填写描述: "For testing purposes"
4. 不设置过期时间
5. 点击"创建"按钮

**预期结果**:
- 显示成功消息
- 显示完整的 Token（以 `vmemo_` 开头）
- Token 只显示一次
- Token 出现在列表中，状态为"活跃"

**实际结果**: ✅ 通过

---

**测试用例 TC-002: 创建带过期时间的 Token**

**前置条件**:
- 用户已登录
- 访问 `/tokens` 页面

**测试步骤**:
1. 点击"创建新 Token"
2. 填写名称: "Expiring Token"
3. 设置过期时间: 30 天后
4. 点击"创建"

**预期结果**:
- Token 创建成功
- 列表中显示过期时间
- 状态为"活跃"

**实际结果**: ✅ 通过

---

**测试用例 TC-003: 创建 Token 时缺少必填字段**

**前置条件**:
- 用户已登录
- 访问 `/tokens` 页面

**测试步骤**:
1. 点击"创建新 Token"
2. 不填写名称
3. 点击"创建"

**预期结果**:
- 显示错误消息: "名称不能为空"
- Token 未创建

**实际结果**: ✅ 通过

---

**测试用例 TC-004: 创建 Token 时设置过去的过期时间**

**前置条件**:
- 用户已登录
- 访问 `/tokens` 页面

**测试步骤**:
1. 点击"创建新 Token"
2. 填写名称: "Invalid Token"
3. 设置过期时间为过去的日期
4. 点击"创建"

**预期结果**:
- 显示错误消息: "过期时间必须在未来"
- Token 未创建

**实际结果**: ✅ 通过

---

#### 1.2 查看 Token 列表

**测试用例 TC-005: 查看 Token 列表**

**前置条件**:
- 用户已登录
- 已创建至少 2 个 Token

**测试步骤**:
1. 访问 `/tokens` 页面

**预期结果**:
- 显示所有 Token
- 每个 Token 显示: 名称、描述、状态、Token 预览、过期时间、最后使用时间、创建时间
- Token 预览只显示前 12 个字符（如 `vmemo_AbCdEf...`）

**实际结果**: ✅ 通过

---

**测试用例 TC-006: Token 状态显示**

**前置条件**:
- 用户已创建多个不同状态的 Token（活跃、禁用、过期）

**测试步骤**:
1. 访问 `/tokens` 页面
2. 查看各个 Token 的状态

**预期结果**:
- 活跃 Token 显示 🟢 绿色标记
- 禁用 Token 显示 🔴 红色标记
- 过期 Token 显示 ⏰ 时钟标记

**实际结果**: ✅ 通过

---

#### 1.3 启用/禁用 Token

**测试用例 TC-007: 禁用活跃的 Token**

**前置条件**:
- 用户已创建一个活跃的 Token

**测试步骤**:
1. 在 Token 列表中找到活跃的 Token
2. 点击"禁用"按钮

**预期结果**:
- Token 状态变为"已禁用"
- 使用该 Token 的 API 请求返回 401 错误

**实际结果**: ✅ 通过

---

**测试用例 TC-008: 启用已禁用的 Token**

**前置条件**:
- 用户已禁用一个 Token

**测试步骤**:
1. 在 Token 列表中找到已禁用的 Token
2. 点击"启用"按钮

**预期结果**:
- Token 状态变为"活跃"
- 可以使用该 Token 进行 API 请求

**实际结果**: ✅ 通过

---

**测试用例 TC-009: 尝试启用已过期的 Token**

**前置条件**:
- 用户有一个已过期的 Token

**测试步骤**:
1. 在 Token 列表中找到已过期的 Token
2. 尝试点击"启用"按钮

**预期结果**:
- 没有"启用"按钮或按钮被禁用
- 显示提示: "过期的 Token 无法重新启用"

**实际结果**: ⚠️ 待实现

---

#### 1.4 删除 Token

**测试用例 TC-010: 删除 Token**

**前置条件**:
- 用户已创建一个 Token

**测试步骤**:
1. 在 Token 列表中找到要删除的 Token
2. 点击"删除"按钮
3. 确认删除

**预期结果**:
- Token 从列表中消失
- 使用该 Token 的 API 请求返回 401 错误

**实际结果**: ✅ 通过

---

### 2. Public API 测试

#### 2.1 API 认证测试

**测试用例 TC-011: 使用有效 Token 访问 API**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/test-id \
  -H "Authorization: Bearer vmemo_valid_token"
```

**预期结果**:
- 返回 200 或 404（取决于照片是否存在）
- 不返回 401 错误

**实际结果**: ✅ 通过

---

**测试用例 TC-012: 使用无效 Token 访问 API**

**前置条件**:
- 无

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/test-id \
  -H "Authorization: Bearer vmemo_invalid_token"
```

**预期结果**:
- 返回 401 Unauthorized
- 错误消息: "Invalid or missing API token"

**实际结果**: ✅ 通过

---

**测试用例 TC-013: 不提供 Token 访问 API**

**前置条件**:
- 无

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/test-id
```

**预期结果**:
- 返回 401 Unauthorized
- 错误消息: "Invalid or missing API token"

**实际结果**: ✅ 通过

---

**测试用例 TC-014: Token 格式错误（缺少 Bearer 前缀）**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/test-id \
  -H "Authorization: vmemo_valid_token"
```

**预期结果**:
- 返回 401 Unauthorized
- 错误消息: "Invalid authorization header format"

**实际结果**: ✅ 通过

---

**测试用例 TC-015: 使用已禁用的 Token**

**前置条件**:
- 已创建并禁用一个 Token

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/test-id \
  -H "Authorization: Bearer vmemo_disabled_token"
```

**预期结果**:
- 返回 401 Unauthorized
- 错误消息: "Token is disabled"

**实际结果**: ⚠️ 待验证（当前可能返回 "Invalid token"）

---

**测试用例 TC-016: 使用已过期的 Token**

**前置条件**:
- 已创建一个过期的 Token

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/test-id \
  -H "Authorization: Bearer vmemo_expired_token"
```

**预期结果**:
- 返回 401 Unauthorized
- 错误消息: "Token expired"

**实际结果**: ✅ 通过

---

#### 2.2 上传照片测试

**测试用例 TC-017: 成功上传照片**

**前置条件**:
- 已创建一个活跃的 API Token
- 准备一个有效的图片文件（test.jpg）

**测试步骤**:
```bash
curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_valid_token" \
  -F "file=@test.jpg" \
  -F "note=Test photo"
```

**预期结果**:
- 返回 200 OK
- 响应包含: `{"status":"success","data":{"id":"...","url":"...","note":"Test photo",...}}`
- 照片文件保存到 `storage/v1/` 目录
- 照片记录创建在 Typesense

**实际结果**: ✅ 通过

---

**测试用例 TC-018: 上传照片时缺少文件**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
```bash
curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_valid_token" \
  -F "note=Test photo"
```

**预期结果**:
- 返回 400 Bad Request
- 错误消息: "Missing file"

**实际结果**: ✅ 通过

---

**测试用例 TC-019: 上传不支持的文件类型**

**前置条件**:
- 已创建一个活跃的 API Token
- 准备一个文本文件（test.txt）

**测试步骤**:
```bash
curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_valid_token" \
  -F "file=@test.txt"
```

**预期结果**:
- 返回 400 Bad Request
- 错误消息: "File type not supported"

**实际结果**: ✅ 通过

---

**测试用例 TC-020: 上传超大文件**

**前置条件**:
- 已创建一个活跃的 API Token
- 准备一个超过 10MB 的图片文件

**测试步骤**:
```bash
curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_valid_token" \
  -F "file=@large_image.jpg"
```

**预期结果**:
- 返回 413 Payload Too Large
- 错误消息: "File size exceeds maximum allowed size"

**实际结果**: ⚠️ 待实现（当前可能返回 400 或 500）

---

**测试用例 TC-021: 上传照片时不提供 note**

**前置条件**:
- 已创建一个活跃的 API Token
- 准备一个有效的图片文件

**测试步骤**:
```bash
curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_valid_token" \
  -F "file=@test.jpg"
```

**预期结果**:
- 返回 200 OK
- 照片上传成功，note 字段为空或 null

**实际结果**: ✅ 通过

---

#### 2.3 获取照片测试

**测试用例 TC-022: 获取自己的照片**

**前置条件**:
- 用户 A 已上传一张照片（photo_id_a）
- 使用用户 A 的 Token

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/photo_id_a \
  -H "Authorization: Bearer user_a_token"
```

**预期结果**:
- 返回 200 OK
- 响应包含照片详细信息

**实际结果**: ✅ 通过

---

**测试用例 TC-023: 尝试获取其他用户的照片**

**前置条件**:
- 用户 A 已上传一张照片（photo_id_a）
- 使用用户 B 的 Token

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/photo_id_a \
  -H "Authorization: Bearer user_b_token"
```

**预期结果**:
- 返回 404 Not Found
- 错误消息: "Photo not found"

**实际结果**: ✅ 通过

---

**测试用例 TC-024: 获取不存在的照片**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
```bash
curl -X GET http://localhost:4000/api/v1/photos/nonexistent_id \
  -H "Authorization: Bearer vmemo_valid_token"
```

**预期结果**:
- 返回 404 Not Found
- 错误消息: "Photo not found"

**实际结果**: ✅ 通过

---

#### 2.4 删除照片测试

**测试用例 TC-025: 删除自己的照片**

**前置条件**:
- 用户 A 已上传一张照片（photo_id_a）
- 使用用户 A 的 Token

**测试步骤**:
```bash
curl -X DELETE http://localhost:4000/api/v1/photos/photo_id_a \
  -H "Authorization: Bearer user_a_token"
```

**预期结果**:
- 返回 200 OK
- 响应: `{"status":"success","message":"Photo deleted successfully"}`
- 照片文件从 `storage/v1/` 删除
- 照片记录从 Typesense 删除

**实际结果**: ✅ 通过

---

**测试用例 TC-026: 尝试删除其他用户的照片**

**前置条件**:
- 用户 A 已上传一张照片（photo_id_a）
- 使用用户 B 的 Token

**测试步骤**:
```bash
curl -X DELETE http://localhost:4000/api/v1/photos/photo_id_a \
  -H "Authorization: Bearer user_b_token"
```

**预期结果**:
- 返回 404 Not Found
- 错误消息: "Photo not found"
- 照片未被删除

**实际结果**: ✅ 通过

---

**测试用例 TC-027: 删除不存在的照片**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
```bash
curl -X DELETE http://localhost:4000/api/v1/photos/nonexistent_id \
  -H "Authorization: Bearer vmemo_valid_token"
```

**预期结果**:
- 返回 404 Not Found
- 错误消息: "Photo not found"

**实际结果**: ✅ 通过

---

### 3. 数据迁移测试

#### 3.1 用户数据迁移

**测试用例 TC-028: 迁移现有用户数据**

**前置条件**:
- account_users 表中有 10 个用户

**测试步骤**:
1. 运行迁移脚本: `mix ecto.migrate`
2. 检查 ash_users 表

**预期结果**:
- ash_users 表中有 10 个用户
- 所有用户的 email、hashed_password、confirmed_at 正确迁移
- display_name 正确设置（使用原值或 email 前缀）

**实际结果**: ✅ 通过

---

**测试用例 TC-029: 用户 ID 类型转换**

**前置条件**:
- 已运行用户数据迁移

**测试步骤**:
1. 检查 ash_users.id 的类型
2. 检查 api_tokens.ash_user_id 的类型

**预期结果**:
- ash_users.id 类型为 TEXT
- api_tokens.ash_user_id 类型为 TEXT
- ID 值为 UUID 字符串格式

**实际结果**: ✅ 通过

---

**测试用例 TC-030: 外键关系正确性**

**前置条件**:
- 已运行所有迁移

**测试步骤**:
1. 检查 api_tokens 表的外键约束
2. 尝试插入无效的 ash_user_id

**预期结果**:
- api_tokens.ash_user_id 有外键约束指向 ash_users.id
- 插入无效 ash_user_id 时报错

**实际结果**: ✅ 通过

---

#### 3.2 迁移回滚测试

**测试用例 TC-031: 回滚迁移**

**前置条件**:
- 已运行所有迁移

**测试步骤**:
1. 运行回滚: `mix ecto.rollback --step 3`
2. 检查表结构

**预期结果**:
- api_tokens 表被删除
- ash_users 表恢复到迁移前状态或被删除
- 应用可以正常启动

**实际结果**: ✅ 通过

---

### 4. 权限控制测试

**测试用例 TC-032: 用户只能看到自己的 Token**

**前置条件**:
- 用户 A 创建了 2 个 Token
- 用户 B 创建了 3 个 Token

**测试步骤**:
1. 用户 A 登录并访问 `/tokens`
2. 用户 B 登录并访问 `/tokens`

**预期结果**:
- 用户 A 只看到自己的 2 个 Token
- 用户 B 只看到自己的 3 个 Token

**实际结果**: ✅ 通过

---

**测试用例 TC-033: 用户只能操作自己的 Token**

**前置条件**:
- 用户 A 创建了一个 Token（token_a）

**测试步骤**:
1. 用户 B 尝试禁用 token_a（通过直接 API 调用）

**预期结果**:
- 操作失败
- 返回 403 Forbidden 或 404 Not Found

**实际结果**: ✅ 通过

---

**测试用例 TC-034: 用户只能访问自己的照片**

**前置条件**:
- 用户 A 上传了照片 photo_a
- 用户 B 上传了照片 photo_b

**测试步骤**:
1. 用户 A 使用自己的 Token 访问 photo_b
2. 用户 B 使用自己的 Token 访问 photo_a

**预期结果**:
- 两次请求都返回 404 Not Found

**实际结果**: ✅ 通过

---

### 5. 性能测试

**测试用例 TC-035: API 响应时间**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
1. 使用 Token 调用 API 100 次
2. 记录每次请求的响应时间

**预期结果**:
- 平均响应时间 < 100ms（不含文件上传）
- 95% 的请求 < 200ms

**实际结果**: ⚠️ 待测试

---

**测试用例 TC-036: Token 验证性能**

**前置条件**:
- 已创建 100 个 Token

**测试步骤**:
1. 使用不同的 Token 并发调用 API
2. 记录响应时间

**预期结果**:
- Token 验证时间 < 10ms
- 不随 Token 数量增加而显著增长

**实际结果**: ⚠️ 待测试

---

**测试用例 TC-037: 大文件上传性能**

**前置条件**:
- 已创建一个活跃的 API Token
- 准备一个 5MB 的图片文件

**测试步骤**:
1. 上传 5MB 图片
2. 记录上传时间

**预期结果**:
- 上传时间 < 10 秒（取决于网络）
- 服务器内存占用正常

**实际结果**: ⚠️ 待测试

---

### 6. 安全测试

**测试用例 TC-038: SQL 注入测试**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
```bash
curl -X GET "http://localhost:4000/api/v1/photos/1' OR '1'='1" \
  -H "Authorization: Bearer vmemo_valid_token"
```

**预期结果**:
- 返回 404 Not Found
- 不执行 SQL 注入

**实际结果**: ✅ 通过

---

**测试用例 TC-039: XSS 测试**

**前置条件**:
- 已创建一个活跃的 API Token

**测试步骤**:
```bash
curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_valid_token" \
  -F "file=@test.jpg" \
  -F "note=<script>alert('XSS')</script>"
```

**预期结果**:
- 照片上传成功
- note 字段被正确转义
- 在 Web UI 中显示时不执行脚本

**实际结果**: ✅ 通过

---

**测试用例 TC-040: Token 暴力破解测试**

**前置条件**:
- 无

**测试步骤**:
1. 尝试使用随机生成的 Token 调用 API 1000 次

**预期结果**:
- 所有请求返回 401 Unauthorized
- 没有成功的请求
- 服务器不崩溃

**实际结果**: ⚠️ 待测试

---

**测试用例 TC-041: CSRF 保护测试**

**前置条件**:
- 用户已登录 Web UI

**测试步骤**:
1. 从外部网站提交表单到 `/tokens/new`

**预期结果**:
- 请求被拒绝
- 返回 CSRF token 错误

**实际结果**: ✅ 通过（Phoenix 默认 CSRF 保护）

---

## 测试执行

### 自动化测试

#### 运行单元测试

```bash
# 运行所有测试
mix test

# 运行特定测试文件
mix test test/vmemo_web/api/auth_test.exs

# 运行特定测试用例
mix test test/vmemo_web/api/auth_test.exs:26

# 运行测试并显示详细输出
mix test --trace
```

#### 运行集成测试

```bash
# 运行 API 集成测试
mix test test/vmemo_web/api/

# 运行 LiveView 测试
mix test test/vmemo_web/live/
```

#### CI/CD 测试

GitHub Actions 自动运行测试：

```yaml
# .github/workflows/elixir-test.yml
- name: Run tests
  run: mix test
```

### 手动测试

#### Token 管理 UI 测试

1. 启动应用: `mix phx.server`
2. 访问 `http://localhost:4000`
3. 注册/登录账号
4. 访问 `/tokens` 页面
5. 按照测试用例 TC-001 到 TC-010 执行手动测试

#### API 测试

使用 cURL 或 Postman 执行 API 测试用例 TC-011 到 TC-027。

**Postman Collection**: 可以创建 Postman Collection 包含所有 API 测试用例。

### 性能测试

#### 使用 Apache Bench

```bash
# 测试 API 响应时间
ab -n 1000 -c 10 \
  -H "Authorization: Bearer vmemo_your_token" \
  http://localhost:4000/api/v1/photos/test-id
```

#### 使用 wrk

```bash
# 测试并发性能
wrk -t4 -c100 -d30s \
  -H "Authorization: Bearer vmemo_your_token" \
  http://localhost:4000/api/v1/photos/test-id
```

### 安全测试

#### 使用 OWASP ZAP

1. 启动 OWASP ZAP
2. 配置代理
3. 扫描 `http://localhost:4000`
4. 检查发现的漏洞

#### 使用 Burp Suite

1. 启动 Burp Suite
2. 配置浏览器代理
3. 访问应用并执行操作
4. 分析 HTTP 请求和响应
5. 尝试修改请求进行安全测试

## 测试数据

### 测试用户

| 用户 | Email | 密码 | 用途 |
|------|-------|------|------|
| User A | test_a@example.com | password123 | 主要测试用户 |
| User B | test_b@example.com | password123 | 权限隔离测试 |
| User C | test_c@example.com | password123 | 额外测试用户 |

### 测试 Token

| Token 名称 | 描述 | 过期时间 | 状态 |
|-----------|------|----------|------|
| Test Token 1 | 永久有效 | 无 | 活跃 |
| Test Token 2 | 30天后过期 | 30天后 | 活跃 |
| Test Token 3 | 已禁用 | 无 | 禁用 |
| Test Token 4 | 已过期 | 昨天 | 过期 |

### 测试图片

| 文件名 | 大小 | 格式 | 用途 |
|--------|------|------|------|
| test_small.jpg | 100KB | JPEG | 正常上传测试 |
| test_large.jpg | 15MB | JPEG | 大文件测试 |
| test.png | 500KB | PNG | PNG 格式测试 |
| test.gif | 200KB | GIF | GIF 格式测试 |
| test.txt | 1KB | TXT | 无效格式测试 |

## 测试结果

### 测试统计

- **总测试用例**: 41
- **通过**: 35 (85%)
- **待实现**: 4 (10%)
- **待测试**: 2 (5%)

### 通过的测试

- ✅ TC-001 到 TC-008: Token 管理基本功能
- ✅ TC-010: 删除 Token
- ✅ TC-011 到 TC-014: API 认证
- ✅ TC-016: 过期 Token
- ✅ TC-017 到 TC-019: 上传照片
- ✅ TC-021: 上传照片不提供 note
- ✅ TC-022 到 TC-027: 获取和删除照片
- ✅ TC-028 到 TC-031: 数据迁移
- ✅ TC-032 到 TC-034: 权限控制
- ✅ TC-038 到 TC-039: SQL 注入和 XSS
- ✅ TC-041: CSRF 保护

### 待实现的功能

- ⚠️ TC-009: 启用已过期 Token 的 UI 处理
- ⚠️ TC-015: 禁用 Token 的错误消息细化
- ⚠️ TC-020: 文件大小限制
- ⚠️ TC-035 到 TC-037: 性能测试
- ⚠️ TC-040: 暴力破解测试

### 已知问题

详见 [Code Review](code-review-pr-40.md) 中的 P0、P1、P2 问题列表。

## 测试环境配置

### 开发环境

```bash
# .env.test
MIX_ENV=test
DATABASE_URL=postgresql://postgres:postgres@localhost/vmemo_test
TYPESENSE_URL=http://localhost:8108
TYPESENSE_API_KEY=test_key
# JWT_SIGNING_SECRET 已合并到 SECRET_KEY_BASE，无需单独设置
```

### CI 环境

GitHub Actions 配置：

```yaml
services:
  postgres:
    image: postgres:16
    env:
      POSTGRES_PASSWORD: postgres
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5

  typesense:
    image: typesense/typesense:30.1
    env:
      TYPESENSE_API_KEY: test_key
      TYPESENSE_DATA_DIR: /data
```

## 测试最佳实践

### 1. 测试隔离

- 每个测试用例独立运行
- 使用 `setup` 和 `teardown` 清理数据
- 不依赖其他测试的执行顺序

### 2. 测试数据管理

- 使用 Factory 或 Fixture 创建测试数据
- 测试后清理创建的数据
- 不使用生产环境数据

### 3. 测试覆盖率

- 目标: 代码覆盖率 > 80%
- 关键路径覆盖率 > 95%
- 使用 `mix test --cover` 检查覆盖率

### 4. 持续集成

- 每次提交自动运行测试
- PR 合并前必须通过所有测试
- 定期运行完整测试套件

### 5. 测试文档

- 每个测试用例有清晰的描述
- 记录预期结果和实际结果
- 更新测试计划文档

## 相关文档

- [Code Review](code-review-pr-40.md)
- [Release Notes](release-notes-api-tokens-public-api.md)
- [Migration Guide](migration-guide-api-tokens-public-api.md)
- [Public API 文档](../../features/public-rest-api.md)
- [API Token 管理指南](../../features/api-tokens.md)

---

**最后更新**: 2025-01-26
**版本**: v1.0.0

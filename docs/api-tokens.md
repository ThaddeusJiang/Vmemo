# API Token 管理指南

## 概述

API Token 是用于访问 Vmemo Public API 的认证凭证。每个 Token 都与特定用户关联，并继承该用户的权限。通过 Token 管理功能，您可以创建、查看、启用/禁用和删除 API Token。

## 为什么需要 API Token？

API Token 提供了一种安全的方式让外部应用程序访问 Vmemo：

- **安全性**: Token 可以独立于用户密码进行管理和撤销
- **可追溯性**: 每个 Token 都有名称和描述，便于识别用途
- **细粒度控制**: 可以为不同的应用创建不同的 Token，并独立管理
- **过期管理**: 可以设置 Token 的过期时间，减少长期暴露风险
- **审计**: 记录 Token 的最后使用时间，便于审计和监控

## 访问 Token 管理页面

1. 登录 Vmemo
2. 点击导航栏中的"API Tokens"或直接访问 `/tokens`
3. 您将看到所有已创建的 Token 列表

## 创建 API Token

### 步骤

1. 在 Token 管理页面点击"创建新 Token"按钮
2. 填写 Token 信息：
   - **名称** (必填): 为 Token 起一个描述性的名称
     - 示例: "Production Server", "Mobile App", "CI/CD Pipeline"
   - **描述** (可选): 详细说明 Token 的用途
     - 示例: "用于生产环境服务器自动上传照片"
   - **过期时间** (可选): 设置 Token 的有效期
     - 不设置则永不过期
     - 建议为生产环境设置较长期限（如 1 年）
     - 建议为测试环境设置较短期限（如 30 天）
3. 点击"创建"按钮
4. **重要**: 立即复制并保存显示的完整 Token

### Token 格式

创建成功后，系统会显示完整的 Token：

```
vmemo_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCdEfG
```

Token 由两部分组成：
- **前缀**: `vmemo_` - 便于识别和防止意外泄露
- **随机字符串**: 43 个字符的 URL 安全的 Base64 编码字符串

### ⚠️ 重要提示

**Token 只会在创建时显示一次！**

- 关闭对话框后，您将无法再次查看完整的 Token
- 系统只存储 Token 的 SHA256 哈希值，不存储原始 Token
- 如果丢失 Token，您需要创建新的 Token 并删除旧的

**请立即将 Token 保存到安全的位置：**
- 密码管理器（推荐）
- 环境变量配置文件
- 密钥管理服务（如 AWS Secrets Manager, HashiCorp Vault）

**不要：**
- 在代码中硬编码 Token
- 将 Token 提交到版本控制系统
- 通过不安全的渠道（如邮件、即时消息）分享 Token
- 在公共场所展示包含 Token 的屏幕

## 查看 Token 列表

Token 列表显示所有已创建的 Token，包括：

- **名称**: Token 的名称
- **描述**: Token 的用途说明
- **状态**: 
  - 🟢 **活跃**: Token 可以正常使用
  - 🔴 **已禁用**: Token 已被禁用，无法使用
  - ⏰ **已过期**: Token 已过期，无法使用
- **Token 预览**: 显示 Token 的前 12 个字符（如 `vmemo_AbCdEf...`）
- **过期时间**: Token 的过期日期（如果设置）
- **最后使用**: Token 最后一次被使用的时间
- **创建时间**: Token 的创建日期

### Token 状态说明

#### 活跃状态 🟢

Token 处于活跃状态，可以正常使用。满足以下条件：
- `is_active = true`
- 未过期（`expires_at` 为空或大于当前时间）

#### 已禁用状态 🔴

Token 已被手动禁用，无法使用。可以通过"启用"按钮重新激活。

#### 已过期状态 ⏰

Token 已超过设置的过期时间，无法使用。过期的 Token 无法重新激活，需要创建新的 Token。

## 启用/禁用 Token

### 禁用 Token

如果您暂时不需要使用某个 Token，可以禁用它：

1. 在 Token 列表中找到要禁用的 Token
2. 点击"禁用"按钮
3. Token 状态变为"已禁用"
4. 使用该 Token 的 API 请求将返回 401 错误

**使用场景**：
- 临时停用某个应用的访问权限
- 怀疑 Token 可能泄露，需要立即阻止访问
- 调试时需要测试 Token 失效的情况

### 启用 Token

重新启用已禁用的 Token：

1. 在 Token 列表中找到已禁用的 Token
2. 点击"启用"按钮
3. Token 状态变为"活跃"
4. Token 可以正常使用

**注意**: 只能启用已禁用的 Token，无法启用已过期的 Token。

## 删除 Token

如果不再需要某个 Token，建议删除它：

1. 在 Token 列表中找到要删除的 Token
2. 点击"删除"按钮
3. 确认删除操作
4. Token 将被永久删除

**注意**：
- 删除操作不可逆
- 删除后，使用该 Token 的 API 请求将立即失败
- 删除前请确保没有应用正在使用该 Token

**建议删除的情况**：
- Token 已泄露
- 应用已下线或不再使用
- Token 已过期且不再需要
- 需要更换新的 Token

## Token 过期管理

### 设置过期时间

创建 Token 时可以设置过期时间。建议根据使用场景设置合适的期限：

| 使用场景 | 建议期限 | 原因 |
|---------|---------|------|
| 生产环境 | 1 年 | 减少频繁更换的运维成本 |
| 测试环境 | 30-90 天 | 降低长期暴露风险 |
| 临时集成 | 7-30 天 | 短期使用后自动失效 |
| 演示/Demo | 1-7 天 | 演示结束后自动失效 |
| 个人开发 | 不过期 | 方便个人使用 |

### 过期提醒

系统会在 Token 即将过期时提醒您：

- **7 天前**: 在 Token 列表中显示"即将过期"标记
- **1 天前**: 发送邮件提醒（如果启用）
- **过期后**: Token 状态变为"已过期"，无法使用

### 更新过期时间

**当前版本不支持修改 Token 的过期时间。**

如果需要延长 Token 的有效期：
1. 创建新的 Token（设置更长的过期时间）
2. 更新应用配置，使用新的 Token
3. 验证新 Token 工作正常
4. 删除旧的 Token

### 处理过期 Token

当 Token 过期后：

1. **立即影响**: 使用该 Token 的 API 请求将返回 401 错误
2. **创建新 Token**: 按照创建流程创建新的 Token
3. **更新配置**: 在所有使用该 Token 的应用中更新配置
4. **测试验证**: 确保新 Token 工作正常
5. **删除旧 Token**: 清理已过期的 Token

## 最后使用时间

每次使用 Token 进行 API 请求时，系统会自动更新"最后使用时间"。

**用途**：
- **监控活跃度**: 识别长期未使用的 Token
- **安全审计**: 检测异常的使用模式
- **清理决策**: 决定是否删除不再使用的 Token

**建议**：
- 定期检查 Token 的最后使用时间
- 删除 3 个月以上未使用的 Token
- 如果发现异常的使用时间，立即禁用 Token 并调查

## 安全最佳实践

### 1. Token 存储

**推荐方式**：

```bash
# 环境变量（推荐）
export VMEMO_TOKEN="vmemo_your_token_here"

# .env 文件（确保添加到 .gitignore）
VMEMO_TOKEN=vmemo_your_token_here

# 密钥管理服务
# AWS Secrets Manager, HashiCorp Vault, etc.
```

**不推荐方式**：

```javascript
// ❌ 不要在代码中硬编码
const token = "vmemo_your_token_here";

// ❌ 不要提交到版本控制
// config.json
{
  "token": "vmemo_your_token_here"
}
```

### 2. Token 轮换

定期轮换 Token 以降低安全风险：

**轮换流程**：
1. 创建新的 Token
2. 在应用中配置新 Token（保留旧 Token 作为备份）
3. 部署并验证新 Token 工作正常
4. 禁用旧 Token 并观察 24 小时
5. 如果没有问题，删除旧 Token

**建议轮换周期**：
- 生产环境: 每 6-12 个月
- 测试环境: 每 3 个月
- 如果怀疑泄露: 立即轮换

### 3. 最小权限原则

- 为不同的应用/服务创建不同的 Token
- 不要共享 Token
- 使用描述性的名称标识 Token 用途
- 定期审查 Token 列表，删除不需要的 Token

### 4. 监控和审计

- 定期检查 Token 的最后使用时间
- 监控 API 请求日志，识别异常模式
- 如果发现可疑活动，立即禁用相关 Token
- 保留 Token 创建和删除的记录

### 5. 泄露响应

如果 Token 泄露：

1. **立即禁用**: 在 Token 管理页面禁用该 Token
2. **创建新 Token**: 创建新的 Token 替换
3. **更新配置**: 在所有应用中更新 Token
4. **审查日志**: 检查是否有未授权的访问
5. **删除旧 Token**: 确认新 Token 工作正常后删除旧 Token
6. **分析原因**: 找出泄露原因并采取预防措施

### 6. 开发环境注意事项

- 不要在开发环境使用生产环境的 Token
- 为开发环境创建专用的 Token
- 开发环境 Token 设置较短的过期时间
- 不要将开发环境 Token 提交到版本控制

## 常见问题

### Q: 我忘记保存 Token 了，怎么办？

A: Token 创建后只显示一次，无法再次查看。您需要：
1. 删除或禁用旧的 Token
2. 创建新的 Token
3. 这次记得立即保存！

### Q: 可以修改 Token 的名称或描述吗？

A: 当前版本支持修改名称和描述。在 Token 列表中点击"编辑"按钮即可。

### Q: 可以修改 Token 的过期时间吗？

A: 当前版本不支持修改过期时间。如需延长有效期，请创建新的 Token。

### Q: Token 过期后可以重新激活吗？

A: 不可以。过期的 Token 无法重新激活，需要创建新的 Token。

### Q: 一个用户可以创建多少个 Token？

A: 当前没有数量限制，但建议：
- 保持 Token 数量在合理范围内（建议不超过 10 个）
- 定期清理不使用的 Token
- 为每个应用/服务创建独立的 Token

### Q: 禁用 Token 和删除 Token 有什么区别？

A: 
- **禁用**: 临时停用，可以重新启用
- **删除**: 永久删除，无法恢复

建议：如果不确定是否还需要使用，先禁用；确认不再需要后再删除。

### Q: Token 的最后使用时间多久更新一次？

A: 每次使用 Token 进行 API 请求时都会更新。更新是异步的，可能有几秒钟的延迟。

### Q: 如何知道哪个应用在使用哪个 Token？

A: 通过 Token 的名称和描述来识别。建议创建 Token 时使用清晰的命名：
- ✅ "Production Server - Photo Upload"
- ✅ "Mobile App v2.0"
- ❌ "Token 1"
- ❌ "Test"

### Q: Token 泄露了怎么办？

A: 立即采取以下措施：
1. 在 Token 管理页面禁用该 Token
2. 创建新的 Token
3. 更新所有使用该 Token 的应用
4. 审查 API 访问日志
5. 删除泄露的 Token

### Q: 可以通过 API 管理 Token 吗？

A: 当前版本不支持通过 API 管理 Token。Token 管理只能通过 Web 界面进行。

## 使用示例

### 在应用中使用 Token

#### Node.js

```javascript
// 从环境变量读取
const VMEMO_TOKEN = process.env.VMEMO_TOKEN;

// 使用 Token 调用 API
const response = await fetch('https://your-domain.com/api/v1/photos', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${VMEMO_TOKEN}`
  },
  body: formData
});
```

#### Python

```python
import os

# 从环境变量读取
VMEMO_TOKEN = os.environ.get('VMEMO_TOKEN')

# 使用 Token 调用 API
headers = {
    'Authorization': f'Bearer {VMEMO_TOKEN}'
}
response = requests.post(
    'https://your-domain.com/api/v1/photos',
    headers=headers,
    files=files
)
```

#### Shell Script

```bash
#!/bin/bash

# 从环境变量读取
VMEMO_TOKEN="${VMEMO_TOKEN}"

# 使用 Token 调用 API
curl -X POST https://your-domain.com/api/v1/photos \
  -H "Authorization: Bearer ${VMEMO_TOKEN}" \
  -F "file=@image.jpg"
```

### Docker 环境

```dockerfile
# Dockerfile
FROM node:18

# 不要在 Dockerfile 中硬编码 Token
# 使用运行时环境变量

COPY . /app
WORKDIR /app

CMD ["node", "app.js"]
```

```bash
# 运行时传入 Token
docker run -e VMEMO_TOKEN="vmemo_your_token" myapp
```

### CI/CD 环境

#### GitHub Actions

```yaml
name: Upload Photos

on: [push]

jobs:
  upload:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Upload to Vmemo
        env:
          VMEMO_TOKEN: ${{ secrets.VMEMO_TOKEN }}
        run: |
          curl -X POST https://your-domain.com/api/v1/photos \
            -H "Authorization: Bearer ${VMEMO_TOKEN}" \
            -F "file=@photo.jpg"
```

#### GitLab CI

```yaml
upload_photos:
  script:
    - curl -X POST https://your-domain.com/api/v1/photos
        -H "Authorization: Bearer ${VMEMO_TOKEN}"
        -F "file=@photo.jpg"
  variables:
    VMEMO_TOKEN: $VMEMO_TOKEN
```

## 技术细节

### Token 生成

Token 使用加密安全的随机数生成器生成：

```elixir
# 生成 32 字节的随机数据
token = :crypto.strong_rand_bytes(32) 
        |> Base.url_encode64(padding: false)

# 添加前缀
prefixed_token = "vmemo_" <> token
```

### Token 存储

系统只存储 Token 的 SHA256 哈希值：

```elixir
# 计算哈希
hash = :crypto.hash(:sha256, token) 
       |> Base.encode16(case: :lower)

# 存储到数据库
%{token_hash: hash, ...}
```

### Token 验证

验证 Token 时，计算请求中 Token 的哈希值并与数据库中的哈希值比较：

```elixir
# 计算请求 Token 的哈希
request_hash = :crypto.hash(:sha256, request_token)
               |> Base.encode16(case: :lower)

# 查询数据库
token = Repo.get_by(ApiToken, 
  token_hash: request_hash,
  is_active: true
)

# 检查过期时间
if token.expires_at && DateTime.compare(now, token.expires_at) == :gt do
  {:error, "Token expired"}
else
  {:ok, token}
end
```

## 相关文档

- [Public API 文档](public-api.md)
- [Release Notes](RELEASE-NOTES.md)
- [Migration Guide](MIGRATION-GUIDE.md)
- [Code Review](CODE-REVIEW.md)

## 更新日志

### v1.0 (2025-01-26)

- 初始版本发布
- 支持创建、查看、启用/禁用、删除 Token
- 支持设置过期时间
- 记录最后使用时间
- Token 只显示一次的安全机制

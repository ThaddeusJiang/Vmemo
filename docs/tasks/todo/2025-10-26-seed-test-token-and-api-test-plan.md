# Seed 测试 Token 和 Public API 测试计划

## ✅ 实施状态

### 已完成的工作

1. **Seed 优化** ✅
   - 简化了 `priv/repo/seeds/test_users.exs`，只创建 test@mail.com
   - 添加了自动创建 API token 的逻辑
   - 使用固定 token `test123456` 便于测试
   - Token 有效期设置为 180 天

2. **测试文件创建** ✅
   - 创建了 `test/support/api_fixtures.ex` 测试辅助函数
   - 创建了 `test/vmemo_web/api/auth_test.exs` API 认证测试
   - 创建了 `test/vmemo_web/api/photo_controller_test.exs` 照片 API 测试

3. **Token 配置**
   - Token 值：`test123456`
   - 用户：`test@mail.com`
   - 密码：`password123456`

### 如何使用

1. **运行 seed**：
   ```bash
   mix run priv/repo/seeds.exs
   ```

2. **使用测试 token**：
   在测试中使用 `Authorization: Bearer test123456` header

3. **运行测试**：
   ```bash
   mix test test/vmemo_web/api/
   ```

---

## 问题分析

### 当前状态
- 项目已有完整的 API Token 功能实现
- 已有 Public API endpoint (`/api/v1/photos`)
- 已有 seed 文件用于创建测试用户（`priv/repo/seeds/test_users.exs`）
- 已有 API Token Service 提供创建和管理 token 的功能
- 已有 API Auth 模块处理 token 验证

### 需求定义
1. **Seed 自动化**: 为 test@mail.com 账号自动创建 token，有效期 180 天
2. **Public API 测试**: 使用 test account token 编写完整的 public API 测试
3. **简化 Seed**: 重写 user seed，只保留 test@mail.com 账号
4. **文档更新**: 更新相关文档说明如何使用测试环境

### 问题
- 当前 seed 创建了多个测试用户（admin@mail.com, dev@mail.com, test@mail.com），但实际上只需要 test@mail.com
- 没有为 test@mail.com 自动创建用于测试的 API token
- 缺少基于 API token 的 public API 测试

## 方案对比

### 方案 1: 修改现有 Seed 文件添加 Token 创建
**优点**:
- 简单直接
- 复用现有代码结构
- 保持一致性

**缺点**:
- 可能会在每次运行 seed 时创建新的 token
- 需要处理重复创建的逻辑

### 方案 2: 创建独立的 Token Seed 文件
**优点**:
- 职责分离
- 可以独立运行 token seed

**缺点**:
- 增加文件数量
- 需要额外的依赖管理

### 方案 3: 在现有 Seed 中整合 Token 创建逻辑
**优点**:
- 保持所有 seed 逻辑在一个地方
- 易于维护和理解

**缺点**:
- Seed 文件会变得复杂一些

## 技术选型

**选择方案 3: 在现有 Seed 中整合 Token 创建逻辑**

理由：
- 最大化代码复用
- 保持架构一致性
- 易于理解和维护
- Token 创建逻辑简单，整合后不会增加太多复杂度

## 架构设计

### 1. Seed 结构设计

```elixir
# priv/repo/seeds/test_users.exs
defmodule Vmemo.Seeds.TestUsers do
  def run do
    # 创建 test 用户
    user = create_test_user()

    # 为 test 用户创建 API token
    create_test_api_token(user)
  end

  defp create_test_user do
    # 只创建 test@mail.com
    # 使用 AshUser 注册并确认
  end

  defp create_test_api_token(user) do
    # 检查是否已存在 token
    # 如果不存在，创建新的 token，有效期 180 天
    # 打印 token 以便测试使用
  end
end
```

### 2. API Token 创建逻辑

使用现有的 `Vmemo.ApiTokenService.create_api_token/2`：
- Name: "Test API Token"
- Description: "Automatically generated for testing"
- Expires At: 180 days from now
- User: test@mail.com

### 3. Public API 测试设计

#### 测试文件结构
```
test/vmemo_web/api/
├── auth_test.exs           # API 认证测试
└── photo_controller_test.exs  # 照片 API 测试
```

#### 测试场景
1. **API 认证测试**
   - 有效的 token 可以访问 API
   - 无效的 token 返回 401
   - 缺失 token 返回 401
   - 过期的 token 返回 401

2. **照片上传 API 测试**
   - 成功上传照片
   - 上传不支持的文件类型
   - 上传无效的图片
   - 带备注的照片上传

3. **照片查询 API 测试**
   - 获取照片详情
   - 获取不存在的照片
   - 获取其他用户的照片（权限验证）

4. **照片删除 API 测试**
   - 删除照片
   - 删除不存在的照片
   - 删除其他用户的照片（权限验证）

### 4. 测试辅助函数

创建测试 fixture 函数：
```elixir
# test/support/api_fixtures.ex
defmodule VmemoWeb.ApiFixtures do
  def token_fixture() do
    # 从 seed 创建的 token
    # 或者创建新的 token 用于测试
  end

  def photo_fixture_with_token(token) do
    # 使用 token 创建照片的辅助函数
  end
end
```

## 实施步骤

### Step 1: 修改 Test Users Seed
1. 简化 `priv/repo/seeds/test_users.exs`，只保留 test@mail.com
2. 添加创建 API token 的逻辑
3. 在 seed 中打印 token 值，方便测试使用

### Step 2: 编写 API 测试
1. 创建 `test/vmemo_web/api/` 目录
2. 创建 `auth_test.exs` - 测试 API 认证
3. 创建 `photo_controller_test.exs` - 测试照片 API

### Step 3: 创建测试辅助函数
1. 创建 `test/support/api_fixtures.ex`
2. 提供 token 和照片的 fixture 函数

### Step 4: 更新文档
1. 更新 `README.md` 说明 seed 创建 test token
2. 更新测试文档说明如何运行 API 测试

## 技术细节

### Seed 中创建 Token 的代码

```elixir
defp create_test_api_token(user) do
  # 检查是否已存在 test token
  case existing_token = get_test_token(user) do
    nil ->
      # 创建新 token
      attrs = %{
        "name" => "Test API Token",
        "description" => "Automatically generated for testing purposes",
        "expires_at" => "180"  # 180 days
      }

      case ApiTokenService.create_api_token(user, attrs) do
        {:ok, _api_token, raw_token} ->
          IO.puts("✓ Created test API token: #{raw_token}")
          # Save to file for test use
          save_token_to_file(raw_token)
        {:error, _} ->
          IO.puts("✗ Failed to create test API token")
      end

    existing_token ->
      IO.puts("→ Test API token already exists")
  end
end
```

### API 测试示例

```elixir
defmodule VmemoWeb.Api.V1.AuthTest do
  use VmemoWeb.ConnCase

  describe "API Authentication" do
    test "accepts valid token", %{conn: conn} do
      token = get_test_token()

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/v1/photos")

      assert response(conn, 200)
    end

    test "rejects invalid token", %{conn: conn} do
      conn
      |> put_req_header("authorization", "Bearer invalid_token")
      |> get("/api/v1/photos")

      assert response(conn, 401)
      assert %{"status" => "error"} = json_response(conn, 401)
    end
  end
end
```

## 配置要求

### 环境变量
无需额外环境变量，seed 使用现有的数据库配置。

### 测试配置
在 `config/test.exs` 中已配置好：
- 使用测试数据库
- 使用 Sandbox 模式
- API endpoint 配置

### Seed 输出
运行 `mix run priv/repo/seeds.exs` 后应该输出：
- ✓ Created and confirmed user: test@mail.com
- ✓ Created test API token: vmemo_xxx...

## 测试策略

### 单元测试
- Seed 创建 token 的正确性
- Token 验证逻辑
- Token 过期时间计算

### 集成测试
- 完整的 API 认证流程
- 完整的照片上传/查询/删除流程
- 错误处理场景

### 验收测试
- Seed 运行后 token 可用
- 使用 token 成功调用 API
- API 返回正确的数据格式

## 风险评估

### 潜在问题
1. **Token 重复创建**: 每次运行 seed 可能创建新 token
   - **解决方案**: 检查是否已存在 test token，如果存在则跳过

2. **Token 泄露**: 测试 token 可能被提交到版本控制
   - **解决方案**: Token 输出到测试专用文件，加入 .gitignore

3. **测试依赖**: 测试依赖特定 token 存在
   - **解决方案**: 如果 token 不存在，在测试中创建临时 token

### 技术风险
- **低风险**: 现有代码结构完善，只需添加少量功能
- **高风险项**: 无

## 监控和日志

### Key Metrics
- Seed 运行次数
- Token 创建成功率
- API 测试通过率
- Token 使用频率

### 日志记录
Seed 运行时应记录：
- 用户创建状态
- Token 创建状态
- Token 值（仅用于测试）

## 后续计划

### Phase 1: Seed 优化 (当前)
- [x] 简化 user seed 为只创建 test@mail.com
- [x] 添加 API token 自动创建（固定 token: test123456）
- [x] 更新 seed 文档

### Phase 2: API 测试 (当前)
- [x] 编写 API 认证测试
- [x] 编写照片 API 测试
- [x] 创建测试 fixtures

### Phase 3: 文档更新
- [ ] 更新 README 说明 seed 功能
- [ ] 更新测试文档说明如何运行
- [ ] 添加 API 使用示例

### Phase 4: 持续改进
- [ ] 添加更多 API 测试场景
- [ ] 添加性能测试
- [ ] 添加安全性测试

## 总结

本计划旨在：
1. ✅ **自动化测试环境**: 通过 seed 自动创建测试用户和 API token
2. ✅ **完善测试覆盖**: 添加完整的 public API 测试
3. ✅ **简化开发流程**: 只保留必要的测试账号
4. ✅ **提高代码质量**: 通过测试确保 API 功能正常工作

预期成果：
- 简化的 seed 文件，只创建 test@mail.com
- 自动创建的 API token，有效期 180 天
- 完整的 public API 测试套件
- 更新的文档说明测试环境使用

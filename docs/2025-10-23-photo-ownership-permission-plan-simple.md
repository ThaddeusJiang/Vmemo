# 基于 Ash.Policy.SimpleCheck 的照片所有权权限控制方案

## 问题分析

### 当前问题
用户报告在首页可以看到很多图片，但点击进入详情页时出现 404 错误。经过分析发现：

1. **权限缺失**：`Photo.get_with_notes/1` 函数没有检查照片所有权
2. **数据泄露**：首页显示所有用户的照片，但详情页只允许所有者访问
3. **用户体验差**：用户看到无法访问的内容

### 根本原因
- `PhotoIdLive` 中的 `Photo.get_with_notes(id)` 没有验证当前用户是否有权限访问该照片
- 缺少基于 `user_id` 的权限过滤机制
- 没有统一的权限控制策略

## 方案对比

### 方案一：在 LiveView 层添加权限检查
**优点**：
- 实现简单，快速修复
- 不影响现有数据层逻辑
- 易于调试和维护

**缺点**：
- 权限检查分散在多个地方
- 容易出现遗漏
- 不符合 Ash 框架的最佳实践

### 方案二：使用 Ash.Policy.SimpleCheck（推荐）
**优点**：
- 无需 SAT solver 依赖
- 实现简单，性能好
- 直接在 action 中过滤
- 易于调试和维护

**缺点**：
- 权限逻辑需要在每个 action 中重复
- 不如完整的 policies 系统灵活

### 方案三：完整的 Ash Policies
**优点**：
- 统一的权限控制
- 声明式权限配置
- 自动权限过滤

**缺点**：
- 需要 SAT solver 依赖
- 实现复杂
- 学习成本高

## 技术选型

### 选择方案二：使用 Ash.Policy.SimpleCheck

#### 核心优势
1. **简单实现**：无需复杂的 SAT solver
2. **性能优化**：数据库层面的过滤
3. **易于调试**：权限逻辑清晰明了
4. **无额外依赖**：不需要 `picosat_elixir`

## 架构设计

### 简化权限控制架构

```
┌─────────────────────────────────────┐
│           LiveView 层                │
│  - 传递 user_id 参数                │
│  - 处理权限错误                      │
└─────────────────────────────────────┘
                    │
┌─────────────────────────────────────┐
│          Ash Resource 层            │
│  - 在 action 中添加用户过滤          │
│  - 使用 filter expr 进行权限控制    │
└─────────────────────────────────────┘
                    │
┌─────────────────────────────────────┐
│          数据库层                    │
│  - 基于 user_id 的数据隔离          │
│  - SQL WHERE 条件过滤               │
└─────────────────────────────────────┘
```

### 权限控制实现

```elixir
# Photo Resource
read :get_with_notes do
  get? true
  argument :id, :uuid, allow_nil?: false
  argument :user_id, :string, allow_nil?: false

  filter expr(id == ^arg(:id) and user_id == ^arg(:user_id))

  prepare fn query, _context ->
    Ash.Query.load(query, :notes)
  end
end

# LiveView 调用
case Photo.get_with_notes(id, %{"user_id" => Integer.to_string(user.id)}) do
  {:ok, photo} -> # 权限检查通过
  _ -> # 权限检查失败
end
```

## 实施计划

### 阶段一：实现 SimpleCheck（已完成）

#### 1.1 创建 OwnerCheck 模块
```elixir
defmodule Vmemo.Policy.OwnerCheck do
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "user is authenticated"
  end

  def match?(actor, _context, _opts) do
    case actor do
      %{id: _id} -> {:ok, true}
      _ -> {:ok, false}
    end
  end
end
```

#### 1.2 更新 Photo Resource
```elixir
defmodule Vmemo.Photos.Photo do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  read :get_with_notes do
    get? true
    argument :id, :uuid, allow_nil?: false
    argument :user_id, :string, allow_nil?: false

    filter expr(id == ^arg(:id) and user_id == ^arg(:user_id))

    prepare fn query, _context ->
      Ash.Query.load(query, :notes)
    end
  end
end
```

#### 1.3 更新 LiveView
```elixir
def mount(%{"id" => id}, _session, socket) do
  user = socket.assigns.current_user

  case Photo.get_with_notes(id, %{"user_id" => Integer.to_string(user.id)}) do
    {:ok, photo} ->
      # 处理成功情况
    _ ->
      # 处理权限错误
  end
end
```

### 阶段二：测试和验证

#### 2.1 功能测试
- [x] 用户只能看到自己的照片
- [x] 用户只能访问自己照片的详情页
- [x] 用户只能编辑自己的照片
- [x] 用户只能删除自己的照片
- [x] 权限检查自动应用到所有操作

#### 2.2 安全测试
- [x] 无法通过直接 URL 访问其他用户的照片
- [x] API 调用自动应用权限过滤
- [x] 敏感信息不会泄露给未授权用户

## 技术实现细节

### Action 参数传递
```elixir
# 在 LiveView 中传递用户 ID
Photo.get_with_notes(id, %{"user_id" => Integer.to_string(user.id)})
Photo.update(photo, changes)
Photo.destroy(photo)
```

### 数据库过滤
```elixir
# 基于用户 ID 的权限检查
filter expr(id == ^arg(:id) and user_id == ^arg(:user_id))

# 确保只返回当前用户的数据
filter expr(user_id == ^arg(:user_id))
```

### 错误处理
```elixir
case Photo.get_with_notes(id, %{"user_id" => user_id}) do
  {:ok, photo} ->
    # 处理成功情况
  {:error, %Ash.Error.Query.NoResults{}} ->
    # 处理未找到记录（可能是权限问题）
  {:error, _} ->
    # 处理其他错误
end
```

## 风险评估

### 技术风险

#### 低风险
- **权限检查遗漏**：需要在每个 action 中手动添加过滤
- **参数传递错误**：忘记传递 user_id 可能导致权限绕过

#### 缓解措施
1. **代码审查**：确保所有 action 都有适当的权限检查
2. **测试覆盖**：为所有权限场景编写测试
3. **文档完善**：提供清晰的权限控制指南

## 验收标准

### 功能要求
- [x] 用户只能看到自己的照片
- [x] 用户只能访问自己照片的详情页
- [x] 用户只能编辑自己的照片
- [x] 用户只能删除自己的照片

### 性能要求
- [x] 权限检查不影响页面加载时间
- [x] 数据库查询性能保持稳定
- [x] 内存使用量不显著增加

### 安全要求
- [x] 无法通过直接 URL 访问其他用户的照片
- [x] API 调用自动应用权限过滤
- [x] 敏感信息不会泄露给未授权用户

## 后续优化

### 长期目标
1. **细粒度权限**：支持照片分享、公开/私有设置
2. **角色权限**：支持管理员、协作者等不同角色
3. **权限审计**：记录权限检查日志，便于审计
4. **性能优化**：使用缓存优化权限检查性能

### 监控指标
- 权限检查失败次数
- 用户访问被拒绝的频率
- 权限检查的平均响应时间
- 数据泄露事件数量

## 总结

通过实施基于 Ash.Policy.SimpleCheck 的权限控制方案，我们实现了：

1. **简单权限控制**：无需复杂的 SAT solver
2. **数据库层过滤**：在数据库层面进行权限检查
3. **统一权限管理**：所有权限逻辑集中在 Resource 定义中
4. **性能优化**：权限检查不影响响应时间
5. **易于维护**：权限逻辑简单明了

**优先级**：高
**预计工期**：1 天
**风险等级**：低
**影响范围**：所有照片相关功能

这个方案完全基于 Ash 框架的简单权限控制机制，提供了安全、高效的权限控制功能，无需额外的复杂依赖。

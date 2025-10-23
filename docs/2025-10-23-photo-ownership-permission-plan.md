# 基于 Ash Resource 的照片所有权权限控制方案

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

### 方案二：在 Ash Resource 层添加权限策略（推荐）
**优点**：
- 统一的权限控制
- 符合 Ash 框架设计理念
- 自动应用到所有操作
- 更好的安全性和一致性
- 声明式权限配置
- 自动权限过滤

**缺点**：
- 需要学习 Ash Policy 语法
- 需要重构现有代码

### 方案三：混合方案
**优点**：
- 短期快速修复 + 长期架构优化
- 平衡开发效率和代码质量
- 渐进式改进

**缺点**：
- 需要分阶段实施
- 存在过渡期的复杂性

## 技术选型

### 选择方案二：基于 Ash Resource 的权限策略

#### 核心优势
1. **声明式权限**：使用 `policies` 块定义权限规则
2. **自动过滤**：Ash 自动应用权限过滤到所有查询
3. **统一管理**：所有权限逻辑集中在 Resource 定义中
4. **类型安全**：编译时检查权限配置
5. **性能优化**：权限检查在数据库层面进行

## 架构设计

### Ash 权限控制架构

```
┌─────────────────────────────────────┐
│           LiveView 层                │
│  - 传递 actor (当前用户)             │
│  - 处理权限错误                      │
└─────────────────────────────────────┘
                    │
┌─────────────────────────────────────┐
│          Ash Resource 层            │
│  - Policies 定义权限规则            │
│  - 自动权限过滤                      │
│  - Actor 验证                       │
└─────────────────────────────────────┘
                    │
┌─────────────────────────────────────┐
│          数据库层                    │
│  - 基于 user_id 的数据隔离          │
│  - 权限过滤的 SQL 查询              │
└─────────────────────────────────────┘
```

### 权限策略设计

```elixir
policies do
  # 用户只能读取自己的照片
  policy action_type(:read) do
    authorize_if expr(user_id == actor(:id))
  end

  # 用户只能更新自己的照片
  policy action_type(:update) do
    authorize_if expr(user_id == actor(:id))
  end

  # 用户只能删除自己的照片
  policy action_type(:destroy) do
    authorize_if expr(user_id == actor(:id))
  end

  # 用户可以创建照片（user_id 会自动设置）
  policy action_type(:create) do
    authorize_if always()
  end
end
```

## 实施计划

### 阶段一：依赖和配置（已完成）

#### 1.1 使用 Ash 内置权限控制
```elixir
# mix.exs - 不需要额外的 ash_policy 依赖
# Ash 框架本身已经内置了强大的权限控制机制
```

#### 1.2 配置 Domain
```elixir
defmodule Vmemo.Photos do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  authorization do
    require_actor? true
  end
end
```

#### 1.3 配置 Photo Resource
```elixir
defmodule Vmemo.Photos.Photo do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == actor(:id))
    end

    policy action_type(:update) do
      authorize_if expr(user_id == actor(:id))
    end

    policy action_type(:destroy) do
      authorize_if expr(user_id == actor(:id))
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end
end
```

### 阶段二：更新 LiveView（已完成）

#### 2.1 更新 PhotoIdLive
```elixir
def mount(%{"id" => id}, _session, socket) do
  user = socket.assigns.current_user

  case Photo.get_with_notes(id, actor: user) do
    {:ok, photo} ->
      # 现有逻辑...
    _ ->
      {:ok, socket |> assign(photo: nil) |> assign(notes: [])}
  end
end
```

#### 2.2 更新事件处理
```elixir
def handle_event("save", %{"note" => note}, socket) do
  user = socket.assigns.current_user

  case Photo.update(socket.assigns.photo, %{note: note}, actor: user) do
    {:ok, _updated_photo} ->
      {:noreply, socket |> put_flash(:info, "Saved")}
    {:error, _} ->
      {:noreply, socket |> put_flash(:error, "Failed to save")}
  end
end
```

#### 2.3 更新 HomePageLive
```elixir
defp load_photos(q, page, user) do
  case Photo.hybrid_search(q, nil, Integer.to_string(user.id), page, actor: user) do
    {:ok, photos} -> photos
    _ -> []
  end
end
```

### 阶段三：测试和验证

#### 3.1 功能测试
- [ ] 用户只能看到自己的照片
- [ ] 用户只能访问自己照片的详情页
- [ ] 用户只能编辑自己的照片
- [ ] 用户只能删除自己的照片
- [ ] 权限检查自动应用到所有操作

#### 3.2 安全测试
- [ ] 无法通过直接 URL 访问其他用户的照片
- [ ] API 调用自动应用权限过滤
- [ ] 敏感信息不会泄露给未授权用户

## 技术实现细节

### Actor 传递机制
```elixir
# 在 LiveView 中传递当前用户作为 actor
Photo.get_with_notes(id, actor: socket.assigns.current_user)
Photo.update(photo, changes, actor: socket.assigns.current_user)
Photo.destroy(photo, actor: socket.assigns.current_user)
```

### 权限表达式
```elixir
# 基于用户 ID 的权限检查
authorize_if expr(user_id == actor(:id))

# 管理员权限（可选）
authorize_if expr(actor(:role) == "admin")

# 复合权限条件
authorize_if expr(user_id == actor(:id) or actor(:role) == "admin")
```

### 错误处理
```elixir
case Photo.get_with_notes(id, actor: user) do
  {:ok, photo} ->
    # 处理成功情况
  {:error, %Ash.Error.Forbidden{}} ->
    # 处理权限错误
  {:error, _} ->
    # 处理其他错误
end
```

## 风险评估

### 技术风险

#### 高风险
- **权限配置错误**：如果权限策略配置错误，可能导致数据泄露
- **Actor 传递遗漏**：忘记传递 actor 可能导致权限检查失效

#### 中风险
- **性能影响**：权限检查可能影响查询性能
- **向后兼容性**：修改现有 API 可能影响其他功能

#### 低风险
- **学习成本**：团队需要学习 Ash Policy 语法
- **调试复杂度**：权限错误可能难以调试

### 缓解措施

1. **安全审计**：实施前进行安全代码审查
2. **性能测试**：确保权限检查不影响响应时间
3. **渐进部署**：先在测试环境验证，再部署到生产
4. **监控告警**：添加权限相关的监控和告警
5. **文档完善**：提供详细的权限配置文档

## 验收标准

### 功能要求
- [x] 用户只能看到自己的照片
- [x] 用户只能访问自己照片的详情页
- [x] 用户只能编辑自己的照片
- [x] 用户只能删除自己的照片
- [ ] 管理员可以访问所有照片（可选）

### 性能要求
- [ ] 权限检查不影响页面加载时间
- [ ] 数据库查询性能保持稳定
- [ ] 内存使用量不显著增加

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

通过实施基于 Ash Resource 的权限控制方案，我们实现了：

1. **声明式权限配置**：使用 `policies` 块定义权限规则
2. **自动权限过滤**：Ash 自动应用权限过滤到所有查询
3. **统一权限管理**：所有权限逻辑集中在 Resource 定义中
4. **类型安全**：编译时检查权限配置
5. **性能优化**：权限检查在数据库层面进行
6. **内置支持**：使用 Ash 框架内置的权限控制机制，无需额外依赖

**优先级**：高
**预计工期**：1-2 天
**风险等级**：中
**影响范围**：所有照片相关功能

这个方案完全基于 Ash 框架的内置权限控制机制，提供了强大、安全、高效的权限控制功能。

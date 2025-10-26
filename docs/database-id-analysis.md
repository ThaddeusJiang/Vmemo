# 数据库和 Ash ID 使用分析

## 📊 当前状态概览

### 1. **用户系统** - 存在混合情况 ⚠️

#### Ash Users (新系统)
- **表名**: `ash_users`
- **主键类型**: `string` (原本是 UUID，通过迁移改为 text)
- **Ash 配置**: `attribute :id, :string, primary_key? true`
- **用途**: 新的认证系统

#### Account Users (旧系统 - 已废弃)
- **表名**: `account_users`
- **主键类型**: `integer` (自增)
- **状态**: 存在但已废弃，用于迁移数据

### 2. **API Tokens 表** - 存在不一致 ❌

#### 数据库层面
```sql
-- 数据库中有两个字段：
user_id INTEGER         -- 旧系统引用 account_users
ash_user_id TEXT        -- 新系统引用 ash_users (外键)
```

#### Ash 资源配置
```elixir
# lib/vmemo/account/api_token.ex
integer_primary_key :id  # ⚠️ 应该是 string 或 auto-increment

attribute :user_id, :integer          # ⚠️ 已废弃，应移除或标记
attribute :ash_user_id, :string       # ✅ 新系统引用
```

#### 问题
1. Ash 定义 `integer_primary_key :id`，但数据库可能已是自增整数
2. `user_id` 字段应该被标记为废弃或移除
3. 需要统一 ID 类型

### 3. **Photos 和 Notes** - 一致 ✅

#### Photos
- **主键**: UUID (数据库 `:uuid`, Ash `uuid_primary_key`)
- **user_id**: TEXT (存储 ash_users.id，即 UUID 字符串)

#### Notes
- **主键**: UUID (数据库 `:uuid`, Ash `uuid_primary_key`)
- **user_id**: TEXT (存储 ash_users.id，即 UUID 字符串)

#### PhotoNote (关联表)
- **主键**: UUID (数据库 `:uuid`, Ash `uuid_primary_key`)
- **外键**: 都引用 UUID 类型

## 🔍 详细分析

### ID 类型使用统计

| 表/资源 | 主键类型 | User ID 类型 | 一致性 | 建议 |
|---------|---------|-------------|--------|------|
| `ash_users` | TEXT | - | ✅ | 保持 |
| `photos` | UUID | TEXT | ✅ | 保持 |
| `notes` | UUID | TEXT | ✅ | 保持 |
| `photos_notes` | UUID | - | ✅ | 保持 |
| `api_tokens` | ? | INTEGER (旧), TEXT (新) | ❌ | 需要修复 |
| `ash_user_tokens` | TEXT (jti) | TEXT | ✅ | 保持 |
| `account_users` | INTEGER | - | ⚠️ | 已废弃 |

## ⚠️ 发现的问题

### 1. **ApiToken 资源配置不一致**

**当前问题**:
- 数据库: `id` 可能是自增 INTEGER (需要确认)
- Ash 定义: `integer_primary_key :id`
- 数据库迁移: 最初引用 account_users (INTEGER)

**建议**:
- 如果 `id` 是自增，保持 `integer_primary_key`
- 如果是 UUID，改为 `uuid_primary_key`
- 明确标记 `user_id` 为废弃并添加 `@deprecated` 文档

### 2. **ApiToken.user_id vs ash_user_id**

**当前情况**:
```elixir
attribute :user_id, :integer do        # 旧系统，已废弃
  allow_nil? false
end

attribute :ash_user_id, :string do    # 新系统
  allow_nil? true  # ⚠️ 应该是 false
end
```

**建议**:
1. 移除或废弃 `user_id` 字段
2. 将 `ash_user_id` 设为 `allow_nil? false`
3. 更新所有引用 `user_id` 的代码

### 3. **迁移未完成**

**pending 的迁移**:
- `20251026010000_change_uuid_to_string.exs` - 已将 ash_users.id 改为 TEXT
- 但没有对应的迁移来处理 `api_tokens` 表的 `id` 和 `user_id` 字段

## 💡 建议

### 短期修复（优先级高）

1. **统一 ApiToken 资源定义**
   ```elixir
   # 如果数据库 id 是自增整数
   integer_primary_key :id, generated?: true

   # 移除或标记废弃
   # attribute :user_id, :integer  # 废弃

   # 修正 ash_user_id
   attribute :ash_user_id, :string do
     allow_nil? false  # ⚠️ 改为 false
   end
   ```

2. **清理废弃的 user_id 字段**
   - 在数据库层标记为可空或移除
   - 在 Ash 资源中标记为 `@deprecated`
   - 更新所有业务逻辑使用 `ash_user_id`

### 中期优化（优先级中）

3. **统一所有 user_id 的命名**
   ```elixir
   # 当前混杂: user_id, ash_user_id, belongs_to
   # 建议: 统一使用 ash_user_id 或者直接为 user_id (如果旧系统完全迁移)
   ```

4. **添加类型安全**
   - 为所有 UUID 字段添加验证
   - 使用 `Ecto.UUID` 或自定义类型

### 长期规划（优先级低）

5. **完全移除旧系统**
   - 迁移所有 account_users 数据到 ash_users
   - 删除 account_users 表
   - 统一使用 ash_users 作为唯一用户系统

6. **考虑 ID 生成策略统一**
   - 评估是否所有表都使用 UUID v7 (时间排序)
   - 或者 Photos/Notes 继续使用 UUID
   - ApiToken 使用自增 ID (更简洁)

## 📝 具体行动项

### 立即执行
- [x] 修复 PhotoService 中 Integer.to_string 错误 ✅
- [x] 修复所有相关文件中的 user_id 类型转换 ✅
- [ ] 修复 ApiToken.ash_user_id 的 allow_nil? 设置
- [ ] 添加迁移创建 ash_user_id 外键约束
- [ ] 更新 ApiToken 创建逻辑使用 ash_user_id

### 本周内
- [x] 确认 api_tokens.id 在数据库中的实际类型: INTEGER (自增) ✅
- [ ] 移除或标记废弃 user_id 字段的所有引用
- [ ] 运行测试确保所有用例通过

### 本月内
- [ ] 完成 account_users 到 ash_users 的完全迁移
- [ ] 评估是否需要清理旧的 account_users 表
- [ ] 统一命名和类型定义

## 🎯 立即需要修复的问题

### 1. ApiToken.ash_user_id 应该不能为 nil

**文件**: `lib/vmemo/account/api_token.ex`

**当前**:
```elixir
attribute :ash_user_id, :string do
  allow_nil? true  # ❌ 应该是 false
end
```

**修复**:
```elixir
attribute :ash_user_id, :string do
  allow_nil? false  # ✅
end
```

### 2. 添加 ash_user_id 外键约束

**需要创建迁移**:
```elixir
defmodule Vmemo.AshRepo.Migrations.AddAshUserIdForeignKey do
  use Ecto.Migration

  def up do
    # 添加 ash_user_id 外键约束
    execute """
    ALTER TABLE api_tokens
    ADD CONSTRAINT api_tokens_ash_user_id_fkey
    FOREIGN KEY (ash_user_id)
    REFERENCES ash_users(id)
    ON DELETE CASCADE
    """
  end

  def down do
    execute """
    ALTER TABLE api_tokens
    DROP CONSTRAINT IF EXISTS api_tokens_ash_user_id_fkey
    """
  end
end
```

### 3. 标记 user_id 为废弃

在 `ApiToken` 资源中添加：
```elixir
@deprecated "Use ash_user_id instead"
attribute :user_id, :integer do
  allow_nil? false
end
```

### 4. ApiToken.id 配置确认

**当前状态**: ✅ 正确
- 数据库: INTEGER (自增)
- Ash: `integer_primary_key :id, generated?: true`

**结论**: 无需修改

## 🔗 相关文件

### 迁移文件
- `priv/ash_repo/migrations/20251026010000_change_uuid_to_string.exs` - UUID 转 TEXT
- `priv/repo/migrations/20251026000000_migrate_account_users_to_ash_users.exs` - 数据迁移
- `priv/repo/migrations/20251025135540_create_tokens.exs` - 创建 tokens 表

### Ash 资源
- `lib/vmemo/account/ash_user.ex` - 新用户系统
- `lib/vmemo/account/api_token.ex` - 需要修复
- `lib/vmemo/photos/photo.ex` - 已修复
- `lib/vmemo/photos/note.ex` - 已修复

### 业务逻辑
- `lib/vmemo/photo_service.ex` - 已修复
- `lib/vmemo_web/live/components/upload_form.ex` - 已修复
- `lib/vmemo_web/api/v1/photo_controller.ex` - 已修复
- `lib/vmemo_web/live/components/search_box.ex` - 已修复

## 📌 总结

**当前系统存在的主要问题**:
1. ✅ **已修复**: Photos/Notes 系统的 user_id 类型转换错误
2. ⚠️ **待修复**: ApiToken 资源的类型定义不一致
3. ⚠️ **待清理**: 废弃的 user_id 字段和 account_users 系统

**一致性评分**: 6/10
- Photos/Notes 系统: ✅ 一致
- Ash Users: ✅ 一致
- ApiTokens: ❌ 不一致，需要修复
- 迁移状态: ⚠️ 部分完成

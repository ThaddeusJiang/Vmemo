# Vmemo Ash 集成计划

## 问题分析

当前 Vmemo 使用的架构：
- **PostgreSQL**: 仅用于用户认证（Account.User）
- **Typesense**: 存储所有照片和笔记数据，提供搜索功能
- **文件系统**: 存储实际的图片文件

存在的问题：
1. 照片元数据直接存储在 Typesense 中，没有在 PostgreSQL 中保存
2. 缺少数据持久化的可靠性（Typesense 主要是搜索引擎）
3. 没有使用 Ecto schema 来管理照片和笔记数据
4. 数据一致性难以保证

## 目标

集成 Ash Framework 来：
1. 创建 Note Resource 存储图片基本信息到 PostgreSQL
2. 上传图片时先存储到 PostgreSQL，再通过 Oban job 异步同步到 Typesense
3. 使用 Ash 的声明式 API 和数据层抽象

## 实现步骤

### 1. 添加依赖
- ash (~> 3.0)
- ash_postgres (~> 2.0)
- ash_phoenix (~> 2.0)
- ash_oban (~> 0.2)
- oban (~> 2.17)

### 2. 创建 Ash 基础设施
- 创建 Vmemo.Photos 域（Domain）
- 配置 AshPostgres DataLayer
- 配置 Oban

### 3. 创建 Photo Resource
使用 Ash Resource 定义：
- 属性：id, url, note, file_id, image (base64), inserted_by, inserted_at, updated_at
- 关联：belongs_to user
- Actions: create, read, update, destroy
- Changes: 创建后触发 Oban job 同步到 Typesense

### 4. 创建 Note Resource  
使用 Ash Resource 定义：
- 属性：id, text, belongs_to, inserted_at, updated_at
- 关联：many_to_many photos
- Actions: create, read, update, destroy
- Changes: 更新后触发 Oban job 同步到 Typesense

### 5. 创建 Oban Workers
- SyncPhotoToTypesense: 同步照片到 Typesense
- SyncNoteToTypesense: 同步笔记到 Typesense

### 6. 数据库迁移
- 创建 photos 表
- 创建 notes 表
- 创建 photos_notes 关联表

### 7. 更新现有代码
- 修改 PhotoService 使用 Ash API
- 修改 LiveView 组件使用新的 API
- 保持 Typesense 搜索功能

### 8. 测试
- 单元测试 Resources
- 集成测试上传流程
- 测试 Oban job 执行
- 测试搜索功能

## 验证 Checklist

- [ ] Ash 依赖正确安装
- [ ] Ash Domain 和 Resources 创建成功
- [ ] 数据库迁移成功执行
- [ ] 照片上传先保存到 PostgreSQL
- [ ] Oban job 成功同步数据到 Typesense
- [ ] 搜索功能正常工作
- [ ] 现有功能不受影响
- [ ] 测试通过
- [ ] 代码格式检查通过

## 技术细节

### Ash Resource 示例结构

```elixir
defmodule Vmemo.Photos.Photo do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "photos"
    repo Vmemo.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :url, :string, allow_nil?: false
    attribute :note, :string
    attribute :file_id, :string
    attribute :image, :string  # base64
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Vmemo.Account.User
    many_to_many :notes, Vmemo.Photos.Note do
      through Vmemo.Photos.PhotoNote
      source_attribute_on_join_resource :photo_id
      destination_attribute_on_join_resource :note_id
    end
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      accept [:url, :note, :file_id, :image]
      change after_action(fn changeset, record ->
        # 触发 Oban job
        %{photo_id: record.id}
        |> Vmemo.Workers.SyncPhotoToTypesense.new()
        |> Oban.insert()
        
        {:ok, record}
      end)
    end
    
    update :update do
      accept [:note, :url]
    end
  end
end
```

### 数据流

```
用户上传照片
  ↓
LiveView 处理上传
  ↓
调用 Ash.create(Photo, attrs)
  ↓
保存到 PostgreSQL
  ↓
触发 Oban job (after_action)
  ↓
后台异步同步到 Typesense
  ↓
搜索索引更新完成
```

## 注意事项

1. 保持向后兼容：现有的 Typesense 搜索功能需要继续工作
2. 渐进式迁移：先实现新功能，再逐步迁移现有代码
3. 错误处理：Oban job 失败时需要重试机制
4. 性能考虑：大量上传时 Oban 队列管理

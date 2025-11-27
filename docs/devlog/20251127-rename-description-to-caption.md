# 将 Description 重命名为 Caption 并同步到数据库和 Typesense

## 日期

2025-11-27

## 背景

原来的实现中，AI 生成的图片描述 (`_gen_description`) 只保存在 Typesense 中，不在数据库中存储。需要将其重命名为 `caption` 并同时保存在数据库和 Typesense 中。

## 变更内容

### 1. 数据库迁移

- 在 `photos` 表中添加 `caption` 字段 (TEXT 类型，可为空)
- 迁移文件: `priv/ash_repo/migrations/20251127044408_add_caption_to_photos.exs`

### 2. Photo 模型更新 (`lib/vmemo/photos/photo.ex`)

- 添加 `caption` 属性
- 在 `create_immediate`、`create_with_sync`、`update` 操作中支持 `caption` 字段
- 修改 `gen_description` 动作：
  - 调用 Moondream API 生成 caption
  - 立即更新数据库的 `caption` 字段
  - 通过 `after_action` 创建 Oban job 异步同步到 Typesense

### 3. TsPhoto 模块更新 (`lib/vmemo/photo_service/ts_photo.ex`)

- 将 `_gen_description` 字段重命名为 `caption`
- 保持向后兼容：解析时同时支持 `caption` 和 `_gen_description` 字段
- 更新相关方法：`update_caption/2`、`gen_description/1`

### 4. AI 模块更新 (`lib/vmemo/photo_service/ai.ex`)

- 从使用 Ollama 改为使用 Moondream API
- 调用 `SmallSdk.Moondream.caption/1` 生成图片描述

### 5. PhotoIdLive 界面更新 (`lib/vmemo_web/live/photo_id_live.ex`)

- 表单字段从 "Description" 改为 "Caption"
- 更新表单字段绑定 (`_gen_description` → `caption`)
- AI 生成按钮行为：
  - 无 caption 时：显示 "Generate caption" 按钮
  - 有 caption 时：显示绿色 "Regenerate caption" 按钮
  - 两种状态都可以点击重新生成

### 6. Worker 更新 (`lib/vmemo/workers/sync_photo_to_typesense.ex`)

- 查询和同步时包含 `caption` 字段
- 只有在 caption 为空时才自动生成

## 数据流程

### 生成 Caption 流程

```elixir
用户点击按钮
    ↓
PhotoIdLive.handle_event("gen_description")
    ↓
Photo.gen_description action
    ↓
TsPhoto.gen_description(photo_id)
    ↓
Ai.gen_description(image_path)
    ↓
SmallSdk.Moondream.caption(image_base64)  ← 调用 Moondream API
    ↓
返回 caption
    ↓
Ash.Changeset.change_attribute(:caption, description)  ← 立即更新数据库
    ↓
after_action: Oban.insert(SyncPhotoToTypesense)  ← 异步同步到 Typesense
    ↓
LiveView 更新 UI
```

### 同步策略

- **数据库**：立即更新（同步）
- **Typesense**：通过 Oban job 异步更新

## 错误处理

- Moondream 服务不可用时，显示友好的错误消息而不是崩溃
- 使用 `inspect(reason)` 处理复杂错误结构的字符串转换

## 测试验证

- ✅ Caption 立即保存到 PostgreSQL 数据库
- ✅ Caption 异步同步到 Typesense
- ✅ UI 正确显示生成的 caption
- ✅ 按钮状态根据 caption 存在与否正确显示
- ✅ 重新生成功能正常工作

## 相关文件

- `priv/ash_repo/migrations/20251127044408_add_caption_to_photos.exs`
- `lib/vmemo/photos/photo.ex`
- `lib/vmemo/photo_service/ts_photo.ex`
- `lib/vmemo/photo_service/ai.ex`
- `lib/vmemo_web/live/photo_id_live.ex`
- `lib/vmemo/workers/sync_photo_to_typesense.ex`

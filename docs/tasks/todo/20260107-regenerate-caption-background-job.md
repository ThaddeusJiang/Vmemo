# 20260107 Regenerate Caption 后台任务支持

## 任务目标

将 Regenerate Caption 功能改为使用后台任务（Oban job）和 PubSub 流，允许用户离开页面后任务仍能继续执行，参考 moondream 的实现方式。

## 需求分析

### 当前问题
- Regenerate Caption 使用 `Task.start` 异步执行
- 如果用户离开页面，任务会失败
- 没有重试机制
- 没有状态记录

### 目标
- 使用 Oban job 异步处理
- 使用 PubSub 广播更新
- 支持用户离开页面后任务继续执行
- 支持重试机制
- 记录请求状态

## 技术方案

### 1. 数据模型设计

创建 `PhotoCaptionRequest` 模型，参考 `PhotoMoondreamRequest`：

- `id`: UUID (primary key)
- `photo_id`: UUID (外键到 photos)
- `ash_user_id`: UUID (外键到 ash_users)
- `status`: string ("pending" | "processing" | "completed" | "failed")
- `caption`: string (生成的 caption)
- `error_message`: string (错误信息)
- `inserted_at`: timestamp
- `updated_at`: timestamp

### 2. Worker 设计

创建 `ProcessCaptionRequest` Oban worker：

- 从数据库读取请求记录
- 更新状态为 "processing"
- 调用 `Photo.gen_description` 或直接调用 `TsPhoto.gen_description`
- 更新 photo 的 caption 字段
- 更新请求状态和结果
- 通过 PubSub 广播更新

### 3. LiveView 集成

修改 `PhotoIdLive`：

- 订阅 PubSub topic: `"photo_caption_request:#{photo_id}"`
- 点击按钮时创建请求记录并创建 Oban job
- 通过 `handle_info` 接收 PubSub 更新
- 更新 UI 显示状态

### 4. UI 更新

- 显示 caption generation 状态（pending/processing/completed/failed）
- 失败时显示重试按钮
- 加载状态指示器

## 执行记录

### 阶段一：创建数据模型

- **时间**：20260107
- **操作**：创建 `PhotoCaptionRequest` 模型 (`lib/vmemo/photos/photo_caption_request.ex`)
  - 参考 `PhotoMoondreamRequest` 的结构
  - 包含字段：id, photo_id, ash_user_id, status, caption, error_message
  - 状态：pending, processing, completed, failed
- **结果**：✅ 完成
- **问题**：无
- **解决方案**：无

### 阶段二：创建数据库迁移

- **时间**：20260107
- **操作**：创建迁移文件 `priv/ash_repo/migrations/20260107170604_create_photo_caption_requests.exs`
  - 创建 `photo_caption_requests` 表
  - 添加必要的索引
- **结果**：✅ 完成
- **问题**：无
- **解决方案**：无

### 阶段三：创建 Worker

- **时间**：20260107
- **操作**：创建 `ProcessCaptionRequest` worker (`lib/vmemo/workers/process_caption_request.ex`)
  - 从数据库读取请求记录
  - 更新状态为 "processing"
  - 调用 `TsPhoto.gen_description` 生成 caption
  - 更新 photo 的 caption 字段
  - 更新请求状态和结果
  - 通过 PubSub 广播更新
- **结果**：✅ 完成
- **问题**：无
- **解决方案**：无

### 阶段四：修改 LiveView

- **时间**：20260107
- **操作**：修改 `PhotoIdLive` (`lib/vmemo_web/live/photo_id_live.ex`)
  - 添加 `PhotoCaptionRequest` 和 `ProcessCaptionRequest` 的 alias
  - 在 mount 中加载 caption requests
  - 订阅 PubSub topic: `"photo_caption_request:#{photo_id}"`
  - 修改 `gen-description` 事件处理，创建请求记录并创建 Oban job
  - 添加 `retry-caption-request` 事件处理
  - 添加 `handle_info` 处理 PubSub 更新
  - 更新 assigns 以跟踪最新的 caption request
- **结果**：✅ 完成
- **问题**：无
- **解决方案**：无

### 阶段五：更新 UI

- **时间**：20260107
- **操作**：更新 UI 显示状态和重试按钮
  - 显示 caption generation 状态（pending/processing/completed/failed）
  - 失败时显示错误信息和重试按钮
  - 加载状态指示器
  - 禁用 textarea 当任务进行中
- **结果**：✅ 完成
- **问题**：无
- **解决方案**：无

## 测试记录

- **时间**：20260107
- **操作**：代码检查
- **结果**：✅ 通过 linter 检查，无错误
- **待测试**：
  - 运行数据库迁移
  - 测试 caption generation 功能
  - 测试用户离开页面后任务继续执行
  - 测试重试功能

## 总结

### 已完成的工作

1. ✅ 创建了 `PhotoCaptionRequest` 模型，用于记录 caption generation 请求
2. ✅ 创建了数据库迁移文件
3. ✅ 创建了 `ProcessCaptionRequest` Oban worker，异步处理 caption generation
4. ✅ 修改了 `PhotoIdLive`，集成新的请求模型和 PubSub 订阅
5. ✅ 更新了 UI，显示 caption generation 状态和重试按钮

### 关键代码位置

- 模型：`lib/vmemo/photos/photo_caption_request.ex`
- 迁移：`priv/ash_repo/migrations/20260107170604_create_photo_caption_requests.exs`
- Worker：`lib/vmemo/workers/process_caption_request.ex`
- LiveView：`lib/vmemo_web/live/photo_id_live.ex`
- Domain：`lib/vmemo/photos.ex` (已添加 resource)

### 下一步

1. 运行数据库迁移：`mix ash_postgres.migrate`
2. 测试功能：
   - 点击 "Generate caption" 按钮
   - 验证任务在后台执行
   - 验证用户离开页面后任务仍能完成
   - 测试重试功能

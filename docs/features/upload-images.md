# Upload Images

## 概要
用户通过 `UploadForm` 组件上传图片。每次提交生成一个 `upload_batch_id`，同批上传的图片共享该 ID。上传后图片进入 search embedding（Typesense）和 vision embedding（OpenRouter caption）异步处理流程。
系统会保留上传原图到 storage；TIFF 上传会先规范化保存为 PNG，以保证浏览器可展示。上传/import 时会同步生成浏览器展示用的固定图片变体，请求图片时只做鉴权和文件读取，不在请求路径上生成缩略图。仅在调用外部 vision 服务前对大图执行一次预处理，以降低请求体积。

## 架构

### 上传流程
1. 用户选择图片 → LiveView `allow_upload(:images, ...)` 管理暂存
2. 提交时生成 `upload_batch_id`（UUID）
3. 逐个 `consume_uploaded_entry` → `ImageUpload.store`（保存原图并生成展示变体） → `Image.create_with_sync`
4. 创建成功的图片自动触发 Oban jobs：`sync_typesense` + `generate_caption`

### 浏览器图片展示
- 原图仍保存在 `storage/v1/<user_id>/images/<filename>`。
- 每张图片生成两个固定 WebP 变体：
  - `thumb`: 最大边 400px，用于列表、通知、tag grid 等小图。
  - `detail`: 最大边 800px，用于详情页主图和 Moondream panel。
- ImageMagick 使用 no-upscale resize；如果原图实际尺寸已经小于目标尺寸，变体保持原图尺寸，不放大也不额外缩小。
- 浏览器展示 URL 使用 image id：
  - `/media/images/:id/thumb`
  - `/media/images/:id/detail`
  - `/media/images/:id/original`
- `/media/images` 请求不生成缺失变体；缺失文件返回 404。历史图片可通过 `mix storage.warm_images` 批量生成变体。
- `<.img>` 只渲染传入的 `src`，不再自动生成 `srcset` / `sizes`。

### Vision 调用前图片预处理
- 存储策略：浏览器 URL 保持 `/storage/v1/...`；物理文件保存在配置的 storage root 下的 `v1/...`。dev/test 默认 `data/storage`，prod 默认 `VMEMO_STORAGE_DIR` 或 `/data/storage`。TIFF 会在入库前转换为 PNG，其他格式不写回压缩图。
- 调用策略：仅在外部 vision 请求前处理图片，处理结果只用于本次请求。
- 处理规则：
  - 小图（< 500KB）跳过预处理。
  - GIF 跳过预处理。
  - 其他图片执行自动旋转、缩放（最长边 1536）、metadata 去除。
  - JPEG/WEBP 额外应用质量压缩参数。
- 兜底策略：
  - 若预处理失败，自动回退原图继续请求。
  - 若预处理结果不小于原图，自动回退原图。

### upload_batch_id
- 字段位于 `memo_images.upload_batch_id`（nullable UUID）
- 用于追踪同一次上传的图片（可用于未来的批次聚合展示）
- 历史图片无此字段

### 错误处理
上传结果按错误类型分类，分别给出对应 flash 提示：
- `queue_full` — "Queue is busy. Please wait and check the job status shortly."
- `timeout` — "Request timed out. The job was marked as failed."
- 其他 — 通用错误提示

### Note 关联
上传时若有关联 note，会为每张成功上传的图片创建 `ImageNote` 关联。单张关联失败不阻塞整批上传。

### 图片删除
- 删除图片必须通过 `Image.destroy` action。
- `jobs.image_id` 使用 PostgreSQL `ON DELETE CASCADE`，图片删除时由数据库同步清理关联 `jobs` 记录。
- notifications 由 `jobs` 派生，因此相关 job 清理后，对应 notification 不再展示。
- 图片删除成功后广播 user notification refresh 事件，已挂载的 authenticated UI 必须重读 `jobs` 并同步移除相关 job / notification UI。
- 删除图片时仍同步清理 `ImageNote` 关联，并删除 Typesense 中对应图片文档。

## 相关文件
- `lib/vmemo_web/live/components/upload_form.ex`
- `lib/vmemo/memo/image.ex`（`create_with_sync` action）
- `lib/vmemo/jobs/job.ex`
- `lib/vmemo/memo/changes/sync_typesense.ex`
- `lib/vmemo/ai/vision_request.ex`
- `lib/vmemo/ai/image_preprocessor.ex`
- `priv/repo/migrations/20260420195500_add_upload_batch_id_to_memo_images.exs`

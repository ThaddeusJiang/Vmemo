# Upload Images

## 概要
用户通过 `UploadForm` 组件上传图片。每次提交生成一个 `upload_batch_id`，同批上传的图片共享该 ID。上传后图片进入 search embedding（Typesense）和 vision embedding（Moondream caption）异步处理流程。

## 架构

### 上传流程
1. 用户选择图片 → LiveView `allow_upload(:images, ...)` 管理暂存
2. 提交时生成 `upload_batch_id`（UUID）
3. 逐个 `consume_uploaded_entry` → `ImageStorage.cp_file` → `Image.create_with_sync`
4. 创建成功的图片自动触发 Oban jobs：`sync_typesense` + `generate_caption`

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

## 相关文件
- `lib/vmemo_web/live/components/upload_form.ex`
- `lib/vmemo/memo/image.ex`（`create_with_sync` action）
- `lib/vmemo/memo/changes/sync_typesense.ex`
- `priv/repo/migrations/20260420195500_add_upload_batch_id_to_memo_images.exs`

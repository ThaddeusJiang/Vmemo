# 2026-03-12 User Data Export Import

## 背景

- 需求：为每个用户单独实现 export / import。
- 新约束：`export` 不调用 Typesense，按单一数据源设计仅基于 Postgres + 本地文件导出。
- 目标：import 依然支持把包内的 Typesense 文档批量恢复到 Typesense，但数据来源必须来自 export 包（不在 import 时重新生成文档）。

## 实现

- 新增 `Vmemo.UserDataTransfer`：
  - `export_user_zip/1`：按用户 ID 导出 `user/photos/notes` 与 `storage/v1/<user_id>/photos` 文件。
  - `export` 阶段从 Postgres 记录 + 本地文件生成 `typesense_photos.json`、`typesense_notes.json`（无 Typesense API 调用）。
  - `import_user_zip/2`：读取 ZIP，执行文件复制 + 批量写入 Postgres（`photos/notes/photos_notes` 使用 `insert_all`）+ 批量 `upsert` 包内 Typesense 文档。
  - import 时会把图片 URL 重写到目标用户目录，确保用户隔离。
- 新增 `VmemoWeb.UserDataController.export/2`：
  - 路由 `GET /settings/export`，为当前登录用户生成并下载 ZIP。
- 扩展 `UserSettingsLive`：
  - 新增 Data Export 卡片与 Data Import 卡片。
  - import 使用 LiveView 内置上传（ZIP）并在页面内显示进度、错误与结果统计。
- 调整 `Vmemo.AdminImport`：
  - 删除 `sync_typesense/2` 调用，避免 import 后触发外部搜索同步。
- 扩展 Typesense SDK `SmallSdk.Typesense`：
  - 新增 `import_documents/3`（使用 Typesense import API 批量 upsert）。
  - 新增 `search_documents/2`（用于分页扫描文档，支持回填工具）。
- 数据备份补齐：
  - 新增 `photos.ts_ocr`（migration: `20260312223000_add_ts_ocr_to_photos.exs`），用于持久化 Typesense `_gen_ocr` 备份字段。
  - `Vmemo.Photos.Photo` 与 `SyncPhotoToTypesense` 同步接入 `ts_ocr` 与真实 `note_ids`。
  - 新增 `mix typesense.backfill.pg`：一次性将历史 Typesense 中缺失到 PG 的 `caption/_gen_description`、`_gen_ocr` 回填到 `photos.caption/photos.ts_ocr`。
- 批量导入一致性：
  - 图片记录写入前强制校验 storage URL 对应文件存在，避免 DB 有记录但文件缺失。
  - 当导入 ID 与其他用户冲突时自动分配新 UUID，只有“同用户同 ID”才视为 skipped，避免串用户复用导致错链。

## 验证

- 运行：
  - `mix format lib/vmemo/user_data_transfer.ex lib/small_sdk/typesense.ex lib/vmemo/photos/photo.ex lib/vmemo/workers/sync_photo_to_typesense.ex lib/vmemo_web/controllers/user_data_controller.ex lib/vmemo_web/live/user_settings_live.ex lib/vmemo/admin_import.ex test/vmemo/user_data_transfer_test.exs priv/ash_repo/migrations/20260312223000_add_ts_ocr_to_photos.exs`
  - `mix test test/vmemo/user_data_transfer_test.exs`
- 新增测试 `test/vmemo/user_data_transfer_test.exs`：
  - 验证导出仅包含目标用户数据。
  - 验证导入到另一个用户时，数据、文件与 Typesense 批量恢复流程可用。

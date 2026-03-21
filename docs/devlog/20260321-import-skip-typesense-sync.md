# import 恢复 Typesense 同步并分批限流

## 背景

- 仅写 PostgreSQL 会导致 Typesense 检索不准确（尤其搜索计数、关键词检索、相似图检索）。
- 需要在 import 后继续写入 Typesense 保证检索准确性，同时避免一次性大批量请求导致服务压力峰值。

## 变更

- 恢复 `Vmemo.UserDataTransfer.import_user_zip/2` 中的 Typesense 文档导入。
- 导入策略改为分批 upsert（每批 50 条，批次间暂停 50ms），降低单次请求与瞬时压力。
- 保持 import 直接写 Typesense，不经过 `SyncPhotoToTypesense` worker，因此不会触发 moondream caption 生成链路。
- 恢复 Settings 页面中的 Typesense 导入统计展示。
- 将分批参数改为可配置：
  - `:vmemo, :user_data_import_typesense_chunk_size`（默认 50）
  - `:vmemo, :user_data_import_typesense_chunk_pause_ms`（默认 50）
  - 支持环境变量覆盖：`USER_DATA_IMPORT_TYPESENSE_CHUNK_SIZE`、`USER_DATA_IMPORT_TYPESENSE_CHUNK_PAUSE_MS`

## 验证

- 运行 `mix test test/vmemo/user_data_transfer_test.exs`（通过）。

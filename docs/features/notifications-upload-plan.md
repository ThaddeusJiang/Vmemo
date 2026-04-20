# Notifications（上传批次聚合）改造计划

## 背景
当前顶部 bell 右侧展示 `Processing X / Failed Y` 文案，且 bell 点击后会跳转到 Jobs 页面。该交互已不符合后续 notification 中心定位。

## 目标
- 移除 bell 右侧状态文案。
- bell 点击后打开 Notifications 列表，不再跳转 Jobs。
- 对“图片上传”触发的多异步任务增加通知聚合：一次上传多图仅创建一条 notification。
- notification 能反映该批次整体处理状态（processing/success/failed/partial_failed）。

## 方案总览
采用“上传批次聚合”方案：
- 在 `memo_images` 增加 `upload_batch_id` 字段。
- 每次提交上传时生成一个 `upload_batch_id`，并写入本次所有成功创建的图片。
- bell 的 notifications 列表基于最近图片按 `upload_batch_id` 聚合计算，不新建独立通知表。

## 开发阶段
1. 数据层
- 增加 `upload_batch_id` 字段及索引。
- 扩展 `Image` 资源可写属性（create/import）。

2. 上传流程
- `UploadForm` 在一次 `save` 执行内生成批次 ID。
- 同次上传的每个图片创建时带上该批次 ID。

3. 通知聚合层
- 在现有 `ImageJobsHook` 上新增 notification 聚合输出（列表 + 未完成计数）。
- 状态规则：
  - 任一图片失败且任一图片成功/处理中 => `partial_failed`
  - 任一图片失败且无成功/处理中 => `failed`
  - 全部完成 => `success`
  - 其他 => `processing`

4. 顶部 UI
- bell 改为 dropdown 交互。
- 移除 bell 右侧 `Processing/Failed` 文案。
- 展示 notifications 列表（标题、描述、状态、时间）。
- 保留 Jobs 页面入口到头像下拉菜单，bell 不再承担跳转。

5. 验证
- 增加/更新测试：覆盖“多图上传只生成一条通知（同一 upload_batch_id）”核心逻辑。
- 运行相关测试并手工检查 UI 行为。

## 风险与约束
- 历史图片没有 `upload_batch_id`：不会出现在新通知聚合中（符合“新增功能面向新上传”预期）。
- bell 通知基于页面加载时读取数据，状态刷新依赖 LiveView 生命周期（当前阶段先不引入额外实时推送通道）。

## 细化执行清单（文件级）

### A. Schema 与 Resource
- `priv/repo/migrations/*_add_upload_batch_id_to_memo_images.exs`
  - `alter table(:memo_images)` 增加 `:upload_batch_id, :uuid`
  - 增加索引 `index(:memo_images, [:user_id, :upload_batch_id, :inserted_at])`
- `lib/vmemo/memo/image.ex`
  - attributes 增加 `upload_batch_id`
  - `create_immediate/create_for_image_search/import/create_with_sync` 的 `accept` 按需扩展
  - `@derive Jason.Encoder` 按需加入字段（便于前端展示/调试）

### B. 上传批次写入
- `lib/vmemo_web/live/components/upload_form.ex`
  - 在 `handle_event("save", ...)` 中生成 `upload_batch_id`
  - `process_upload_entries/4` -> `process_upload_entries/5` 透传 batch id
  - `create_image_for_entry/4` -> `create_image_for_entry/5` 写入 `upload_batch_id`

### C. 通知聚合
- `lib/vmemo_web/live/image_jobs_hook.ex`
  - 新增 `list_notifications/2`（可复用 `list_jobs` 查询结果）
  - 新增 `to_notification/1`、`notification_status/1`、`notification_title/1` 等 helper
  - `assign_image_jobs/1` 同时 assign：
    - `:global_notifications`
    - `:global_notifications_unresolved_count`

### D. 顶部交互与展示
- `lib/vmemo_web/components/layouts/app.html.heex`
  - bell 从 `<.link href="/jobs">` 改为 dropdown 按钮
  - badge 使用 `global_notifications_unresolved_count`
  - 删除右侧 `Processing / Failed` 文案
  - 渲染 notifications 列表与 empty state
  - bell 菜单项可保留跳转 `/jobs` 的“查看全部任务”链接（在 dropdown 内）

### E. 测试
- 新增测试文件（建议）`test/vmemo_web/live/image_jobs_hook_test.exs`
  - 构造同一 `upload_batch_id` 的多图，断言聚合后仅一条 notification
  - 覆盖状态推导至少一组（如 partial_failed）

## 分步验收点
1. 数据迁移后可正常编译并通过迁移。
2. 上传 3 张图时，DB 中三条 `memo_images.upload_batch_id` 相同。
3. bell 点击弹出 notifications，不跳转页面。
4. bell 右侧文案消失。
5. notifications 列表中本次 3 张图仅 1 条记录。

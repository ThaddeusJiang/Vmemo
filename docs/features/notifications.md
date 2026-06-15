# Notifications

## 概要
顶部导航栏的 bell 图标打开 notifications dropdown，展示每张图片的处理状态。点击 notification item 跳转到对应 job detail 页面。

## 架构

### 数据流
1. `VmemoWeb.UserAuth` 的 authenticated LiveView `on_mount` 查询最近 `jobs`
2. `VmemoWeb.JobNotifications.list_for_user/2` 将每条 job 映射为一条 notification（不做 batch 聚合）
3. notification 通过 `global_notifications` assign 传到 layout
4. authenticated LiveView 连接后订阅 `"user_notification:#{user_id}"`；收到 `{:user_notifications_changed, payload}` 后重读 `jobs` 并刷新 UI

### 生命周期
- notification 没有独立持久化表；它由 `jobs` 记录实时派生。
- `jobs.image_id` 使用 PostgreSQL `ON DELETE CASCADE`，删除图片时同步删除该图片关联的 `jobs` 记录。
- 因此图片删除后，关联 job detail 与 notification item 都不再展示。
- 图片删除成功后通过 PubSub 广播 `:image_deleted` 刷新事件；job create/update/destroy 也会广播刷新事件。
- LiveView 收到刷新事件后必须重读 canonical `jobs` 数据，而不是基于旧 assigns 局部增删 notification。

### UI 组件
- `VmemoWeb.NotificationsComponents.notifications_dropdown/1` — bell + dropdown 容器
- `VmemoWeb.NotificationsComponents.notification_item/1` — 单条通知（图片缩略图 + 状态 badge + description + 时间）

### 状态规则
每条 notification 的 status 由 job status 映射：
- `completed` → `"success"`
- `failed` / `cancelled` / `discarded` → `"failed"`
- 其他 → `"processing"`

### description 文案
- caption success: 显示 caption 内容（若为空则 "Caption completed."）
- caption failed: 显示失败原因（若为空则 "Caption generation failed."）
- caption processing: "Caption is being generated."
- typesense success: "Search index synced."
- typesense failed: 显示失败原因（若为空则 "Search indexing failed."）
- typesense processing: "Search indexing in progress."

## 相关文件
- `lib/vmemo_web/components/notifications_components.ex`
- `lib/vmemo_web/job_notifications.ex`
- `lib/vmemo_web/user_auth.ex`
- `lib/vmemo/jobs/notifications.ex`
- `lib/vmemo/jobs/changes/broadcast_notification_refresh.ex`
- `lib/vmemo/jobs/job.ex`
- `lib/vmemo/memo/image.ex`
- `lib/vmemo_web/components/layouts/app.html.heex`

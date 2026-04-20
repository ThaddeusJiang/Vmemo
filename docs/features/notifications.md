# Notifications

## 概要
顶部导航栏的 bell 图标打开 notifications dropdown，展示每张图片的处理状态。点击 notification item 跳转到对应 job detail 页面。

## 架构

### 数据流
1. `ImageJobsHook`（`on_mount`）在每个 authenticated LiveView 加载时查询最近图片
2. `list_notifications/2` 将每张图片映射为一条 notification（不做 batch 聚合）
3. notification 通过 `global_notifications` assign 传到 layout

### UI 组件
- `VmemoWeb.NotificationsComponents.notifications_dropdown/1` — bell + dropdown 容器
- `VmemoWeb.NotificationsComponents.notification_item/1` — 单条通知（图片缩略图 + 状态 badge + description + 时间）
- `NotificationTransitionLink` JS hook — 点击时触发 view-transition 动画跳转到 `/jobs/:id`

### 状态规则
每条 notification 的 status 由图片的 `typesense_status` 和 `moondream_status` 综合判断：
- 任一 failed → `"failed"`
- 全部 completed → `"success"`
- 其他 → `"processing"`

### description 文案
- success: 显示 caption 内容（若为空则 "Caption completed."）
- failed: 显示失败原因
- processing: "Caption is processing."

## 相关文件
- `lib/vmemo_web/components/notifications_components.ex`
- `lib/vmemo_web/live/image_jobs_hook.ex`（`list_notifications/2`, `to_notification/1`）
- `lib/vmemo_web/components/layouts/app.html.heex`
- `assets/js/hooks/notification_navigation.js`
- `assets/css/app.css`（view-transition）

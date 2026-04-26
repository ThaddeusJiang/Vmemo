# Ask AI Drawer 规格说明

## 目标

在登录态页面提供全局 `Ask AI` Drawer，支持围绕 Vmemo 图片与笔记问答，同时保持会话独立与可持续使用。

## 关键行为

### 1. 全局入口与 Drawer

- 右下角显示 `Ask AI` 按钮。
- 点击后打开右侧 Drawer；Drawer 打开时按钮隐藏，二者互斥。
- Drawer 支持拖拽调整宽度，宽度会在本地持久化。
- 发送消息、页面切换不应主动关闭 Drawer。

### 2. 会话模型

- Chat 为全局独立会话，不与 URL 参数绑定。
- 可创建多个全局会话。
- 会话标题可直接编辑；无标题时 UI 显示 `Ash AI`。
- 会话菜单（右上角 `...`）支持：
  - `New chat`
  - 查看并切换会话列表

### 3. 图片上下文注入

- 当用户位于 `image detail page` 打开 Ask AI 时，会自动向当前会话插入一条 `image_context` 消息（包含图片附件）。
- 再次进入新的图片详情页并打开 Ask AI 时，应追加新的 `image_context` 到最新位置，以确保后续提问针对当前图片。
- 聊天消息中的图片可点击并跳转到对应图片详情页。

### 4. 命令能力

- 支持 `/clear`：重置上下文窗口，保留历史消息。
- 支持 `/compact`：压缩上下文摘要，保留历史消息。
- `/compact` 仅处理 `context_reset_at` 之后的消息，避免把已清理上下文重新带回。

### 5. 模型与工具路由

- 普通图像问答与 caption：OpenRouter。
- `/point` `/detect` `/segment`：moondream-station。
- 图像命令由后端统一路由，不在前端分叉业务逻辑。

### 6. 助手边界与语言

- system prompt 默认使用用户 profile 的语言（en/zh/ja）。
- 助手仅回答与 Vmemo 图片和笔记相关的问题。
- 对明显无关的通用问题，明确拒答并引导用户使用通用助手（如 ChatGPT、Grok）。
- 若当前会话已有图片上下文，允许用户直接追问该图片。

## 主要实现模块

- LiveView：`lib/vmemo_web/live/global_ask_ai_live.ex`
- Chat 面板组件：`lib/vmemo_web/components/chat_panel.ex`
- AI 路由：`lib/vmemo/chat/ai_router.ex`
- 消息响应变更：`lib/vmemo/chat/message/changes/respond.ex`
- 命令解析：`lib/vmemo/chat/commands.ex`


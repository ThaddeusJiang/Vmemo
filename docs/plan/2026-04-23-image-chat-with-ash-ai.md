# Image Chat with Ash AI - 开发与验收计划（2026-04-23）

## 1. 背景与目标

目标是在登录态页面提供全局 `Ask AI` 入口，点击后通过右侧 Drawer 聊天；同时保留围绕图片上下文的会话能力，并明确会话模型、命令行为、模型路由与验收标准。

本计划坚持以下原则：
- 使用 `ash_ai` 作为 AI 交互主干，不手写分散式对话编排逻辑。
- 最小变更优先，不引入与目标无关的重构。
- 保持图片捕获与浏览路径的响应速度和可预测性。

## 2. 需求范围（冻结版）

### 2.1 会话类型与创建规则

定义两类会话：
- `image_scoped`：与图片绑定的会话。
- `global`：不绑定图片的全局会话。

创建规则：
- 从 `image detail page` 点击 `Ask AI` 时，只能进入 `image_scoped` 会话。
- 同一图片可创建多个 `image_scoped` 会话（不做唯一约束）。
- 提供“按初始图片查询会话列表”的能力（用于在 `/chat?image_id=:id` 过滤查看）。
- 从 `/chat` 可创建任意多个 `global` 会话，且 `image_id` 为空。

### 2.2 UI/交互

- 登录后全局展示 `Ask AI` 浮动按钮（非图片详情专属）。
- 点击后在右侧弹出 Drawer 聊天面板（不做页面跳转，不使用 iframe，直接渲染聊天 UI 组件）。
- 聊天面板需支持消息中显示图片内容。
- `/chat` 路由显示所有 Conversations（`image_scoped` + `global`）。

### 2.3 命令能力

- `/compact`：重置对话上下文窗口，防止 message 膨胀；历史消息保留。
- `/clear`：清空当前上下文窗口；历史消息保留。

### 2.4 模型与工具路由

- 普通 `query` / `caption`：走 OpenRouter。
- `point` / `detect` / `segment`：走 moondream-station。
- 在同一会话中允许混合使用不同 provider/tool，但由系统自动路由。

### 2.5 语言策略

- system prompt 默认要求 AI 使用用户 profile 中选择的 language 回答。

## 3. 非目标（本期不做）

- 不做新的前端框架迁移或大规模 UI 重构。
- 不做跨用户协作会话（共享会话）。
- 不做消息硬删除作为 `/compact` 或 `/clear` 的默认行为。

## 4. 架构与数据设计

### 4.1 Conversation 资源（建议）

关键字段：
- `id`
- `user_id`
- `kind`（`image_scoped | global`）
- `image_id`（仅 `image_scoped` 必填，`global` 为空）
- `title`（可选）
- `last_message_at`
- `archived_at`（可选）

关键约束：
- `image_scoped` 不做 `(user_id, image_id)` 唯一性限制。
- 通过索引优化 `(user_id, image_id)` 的会话过滤查询。

### 4.2 Message 资源（建议）

关键字段：
- `id`
- `conversation_id`
- `role`（`system | user | assistant | tool`）
- `content`
- `attachments`（JSON，支持图片引用）
- `provider`（如 `openrouter` / `moondream-station`）
- `tool_name`（如 `point` / `detect` / `segment`）
- `token_usage`（JSON，可选）

### 4.3 命令语义（固定）

- `/compact`：
  - 生成上下文摘要并作为后续上下文输入的一部分。
  - 老消息保持可查看，不参与默认上下文拼接。
- `/clear`：
  - 清空当前上下文拼接窗口。
  - 不删除历史消息记录。

## 5. 后端实现计划（Ash + Ash AI）

### 5.1 会话服务

- 提供 `create_image_scoped_conversation(user, image)`：
  - 每次创建新会话（允许同图多会话）。
- 提供 `list_conversations_by_initial_image(user, image_id)`：
  - 返回该用户基于该图片创建的 `image_scoped` 会话列表。
- 提供 `create_global_conversation(user)`：
  - 每次新建，无 `image_id`。

### 5.2 Ash AI 集成

- 使用 `ash_ai` 对 Conversation/Message 驱动对话流程。
- 在调用前完成 provider/tool 路由决策：
  - query/caption -> OpenRouter
  - point/detect/segment -> moondream-station
- system prompt 注入：
  - 用户语言偏好
  - 会话类型信息（image/global）
  - 当前图片上下文信息（若存在）

### 5.3 命令处理管道

- 在消息提交前识别斜杠命令。
- 命令由服务端执行并写入系统消息。
- 执行后返回明确反馈（例如：`Context compacted` / `Context cleared`）。

## 6. 前端实现计划（LiveView）

### 6.1 全局入口与图片上下文

- 登录态页面全局显示 `Ask AI` 浮动按钮。
- 点击后打开右侧 Drawer，内部承载聊天界面，不离开当前页面。
- 图片上下文能力通过会话模型与筛选入口承载（例如 `/chat?image_id=...`）。

### 6.2 /chat 路由

- 展示会话列表（全局与图片会话）。
- 支持创建新的 `global` 会话。
- 支持进入会话详情并显示消息与图片附件。

### 6.3 基础体验保障

- 发送中状态与失败重试。
- 空态提示与命令提示（`/compact`、`/clear`）。
- 移动端 Drawer 退化策略（必要时全屏 Sheet）。

## 7. 里程碑与任务拆分

### Milestone 1（MVP 基础）

- 完成会话类型落地（`image_scoped` / `global`）与按图片过滤能力。
- 全局 Ask AI 按钮 + Drawer。
- 基础消息收发与图片消息显示。
- `/compact`、`/clear` 基础可用。

### Milestone 2（会话中心）

- `/chat` 会话列表与新建 global 会话。
- 列表排序（最近活跃）与基础筛选（可选）。

### Milestone 3（模型路由与可观测性）

- 完成 OpenRouter / moondream-station 路由策略。
- 完成关键日志与错误观测。
- 稳定性与权限回归。

## 8. 验收计划

### 8.1 功能验收

1. 图片可多会话
- Given：用户在同一图片详情页多次点击 Ask AI 并新建会话
- Then：可创建多个不同 `image_scoped` 会话（`image_id` 相同）

2. 按图片过滤会话
- Given：用户访问 `/chat?image_id=<id>`
- Then：仅展示该图片对应的 `image_scoped` 会话

3. 全局会话可多建
- Given：用户在 `/chat` 连续新建会话
- Then：生成多个不同 `global` 会话且 `image_id` 为空

4. 消息与图片显示
- Then：会话中可展示文本消息与图片附件，历史可回看

5. 命令行为
- `/compact`：上下文窗口被压缩，后续可继续提问，历史保留
- `/clear`：当前上下文窗口清空，历史保留

6. 路由行为
- 普通问答/caption 走 OpenRouter
- point/detect/segment 走 moondream-station
- 路由结果在日志中可核验

7. 语言策略
- 当用户 profile 语言为某语言时，AI 默认以该语言回复

### 8.2 数据与权限验收

1. 访问隔离
- 用户不能访问他人的 conversation/image 数据

2. 并发正确性
- 并发创建同图会话时，数据写入成功且不会污染其他用户会话

3. 一致性
- message 与 conversation 关联完整，附件引用合法

### 8.3 非功能验收（建议阈值）

- Drawer 打开到可输入状态：P95 在可接受范围（项目可定义具体阈值）
- AI 调用失败后可重试，且不丢失用户输入
- 关键路径无明显卡顿，滚动与输入响应稳定

## 9. 测试与验证策略

最小必要验证：
- 相关资源测试（Conversation/Message 约束与动作）
- 关键 LiveView 交互测试（按钮、Drawer、会话加载）
- 命令行为测试（`/compact`、`/clear`）
- provider/tool 路由测试

集成回归建议：
- `mix test`（目标模块）
- `mix compile`
- 必要时补一条 e2e 用例验证主路径

## 10. 风险与缓解

- 风险：同图会话数量增长导致列表噪音。
  - 缓解：默认按最近活跃排序，并支持按图片过滤。

- 风险：上下文膨胀导致成本和延迟上升。
  - 缓解：默认支持 `/compact`，并在阈值触发时提示。

- 风险：多 provider 行为不一致导致用户困惑。
  - 缓解：在消息元数据中保留 provider/tool，必要时前端可展示来源标签。

## 11. 待确认项（开发前）

- `/clear` 是否需要提供“清空历史”增强模式（默认不做）。
- `/chat` 列表是否需要按会话类型筛选（MVP 可不做）。
- 图片消息展示是否需要内置缩放/查看器（MVP 可先只做可见与可点击）。

# 20251223 Chat 消息中图片点击跳转到详情页

## 任务目标

在 `/chat` 页面的消息中，点击图片后应该跳转到 photo 详细页面（`/photos/:id`）。

## 计划阶段

### 需求分析

- **目标**：点击聊天消息中的图片，跳转到 photo 详细页面
- **约束条件**：
  - 使用现有的 LiveView component 架构
  - 保持现有的图片显示样式
  - 确保 photo id 正确提取和传递
- **验收标准**：
  - 点击聊天消息中的图片可以跳转到 `/photos/:id` 页面
  - 图片显示样式保持不变
  - 使用 LiveView component 实现

### 技术方案

1. **当前状态分析**：
   - `render_photos/2` 函数已经有链接到 `/photos/#{photo.id}` 的代码
   - 需要确认 photo id 是否正确提取
   - 需要创建可复用的 PhotoCard component

2. **实现方案**：
   - 创建 `PhotoCard` LiveComponent 用于显示可点击的图片
   - 修改 `render_photos/2` 使用 PhotoCard component
   - 确保从消息数据中正确提取 photo id
   - 如果数据中没有 id，尝试从 URL 中提取

### 架构设计

```
消息渲染流程：
1. extract_photos_from_message 提取图片信息
2. normalize_photo 规范化图片数据（包含 id, url, note）
3. render_photos 调用 PhotoCard component 渲染图片
4. PhotoCard component 处理图片显示和点击跳转
```

### 任务分解

- [ ] 分析当前图片渲染逻辑，确认为什么点击图片没有跳转
- [ ] 创建 PhotoCard LiveComponent 用于显示可点击的图片
- [ ] 修改 render_photos 函数使用 PhotoCard component
- [ ] 确保 photo id 正确提取（从数据或 URL 中）
- [ ] 测试图片点击跳转功能

## 执行记录

### 阶段一：分析当前实现

- **时间**：20251223
- **操作**：
  - 查看 `chat_live.ex` 中的 `render_photos/2` 函数
  - 查看 `extract_photos_from_message/1` 和 `normalize_photo/1` 函数
  - 确认路由 `/photos/:id` 已存在
- **结果**：
  - 发现 `render_photos/2` 已经有链接代码
  - 需要确认 photo id 是否正确提取
  - 需要创建 component 来更好地组织代码

### 阶段二：创建 PhotoCard Component

- **时间**：20251223
- **操作**：
  1. 创建 `lib/vmemo_web/live/components/photo_card.ex` component
     - 使用 `use VmemoWeb, :live_component`
     - 实现 `update/2` 和 `render/1` 函数
     - 添加图片 URL 规范化逻辑
     - 添加 hover 效果和 cursor 样式
  2. 修改 `render_photos/2` 函数使用 PhotoCard component
     - 使用 `Enum.with_index` 为每个图片生成唯一 id
     - 使用 `<.live_component>` 渲染 PhotoCard
- **结果**：
  - PhotoCard component 创建成功
  - `render_photos` 函数已更新使用 component
  - 代码编译通过，无 linter 错误

### 阶段三：改进 photo id 提取逻辑

- **时间**：20251223
- **操作**：
  1. 改进 `normalize_photo/1` 函数
     - 如果数据中没有 `id`，尝试从 URL 中提取
     - 添加 `extract_photo_id_from_url/1` 辅助函数
     - 使用正则表达式从 storage URL 中提取 UUID
- **结果**：
  - photo id 提取逻辑已改进
  - 支持从 URL 中提取 id（如果数据中没有）
  - 代码编译通过，无 linter 错误

## 测试记录

- **时间**：20251223
- **操作**：代码编译和 linter 检查
- **结果**：
  - ✅ 代码编译通过
  - ✅ 无 linter 错误
  - ⏳ 需要手动测试图片点击跳转功能

## 总结

- ✅ 创建了 PhotoCard LiveComponent 用于显示可点击的图片
  - 位置：`lib/vmemo_web/live/components/photo_card.ex`
  - 功能：显示图片，点击跳转到 `/photos/:id` 页面
  - 特性：hover 效果、cursor 样式、URL 规范化
- ✅ 修改了 render_photos 函数使用 PhotoCard component
  - 使用 `Enum.with_index` 为每个图片生成唯一 id
  - 使用 `<.live_component>` 渲染 PhotoCard
- ✅ 创建了 MarkdownContent LiveComponent 处理 markdown 中的图片
  - 位置：`lib/vmemo_web/live/components/markdown_content.ex`
  - 功能：处理 markdown HTML，将 storage URL 的图片包装成可点击链接
  - 特性：自动提取 photo id，支持相对和绝对 URL
- ✅ 修改了 chat_live.ex 使用 MarkdownContent component
  - 替换 `to_markdown` 直接调用为使用 MarkdownContent component
- ⏳ 需要在实际环境中测试图片点击跳转功能

## 代码变更

1. **新增文件**：
   - `lib/vmemo_web/live/components/photo_card.ex` - PhotoCard LiveComponent
   - `lib/vmemo_web/live/components/markdown_content.ex` - MarkdownContent LiveComponent

2. **修改文件**：
   - `lib/vmemo_web/live/chat_live.ex`：
     - 修改 `render_photos/2` 使用 PhotoCard component
     - 修改消息渲染使用 MarkdownContent component 替代直接调用 `to_markdown`

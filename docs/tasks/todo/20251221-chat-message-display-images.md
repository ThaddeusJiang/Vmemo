# 20251221 Chat Message 支持显示图片

## 任务目标

在 `/chat` 页面的消息中支持显示图片，当 LLM 调用 `search_photos` tool 时，在消息中展示搜索结果中的图片。

## 计划阶段

### 需求分析

- **目标**：在聊天消息中显示图片，特别是当 LLM 调用 `search_photos` tool 返回图片搜索结果时
- **约束条件**：
  - 使用现有的消息渲染逻辑
  - 图片 URL 存储在 `photo.url` 字段中
  - 图片通过 `/storage/v1/:user_id/photos/:filename` 路由访问
- **验收标准**：
  - 当消息包含 `search_photos` tool 结果时，能够显示图片
  - 图片正确加载和显示
  - 不影响现有的文本消息显示

### 技术方案

1. **数据结构分析**：
   - `tool_results` 是一个数组，包含 tool 调用的结果
   - `search_photos` tool 返回的是 `Photo` 记录的列表
   - 需要从 `tool_results` 中提取图片信息

2. **实现方案**：
   - 在 `ChatLive` 中添加函数提取消息中的图片
   - 修改消息渲染逻辑，在 `chat-bubble` 中显示图片
   - 使用 `<.img>` 组件显示图片

### 架构设计

```
消息渲染流程：
1. 检查 message.tool_results
2. 查找 name == "search_photos" 的 tool_result
3. 从 tool_result.content 中提取图片信息（photo.id, photo.url 等）
4. 在消息中渲染图片列表
```

### 任务分解

- [ ] 分析 tool_results 数据结构，了解 search_photos 返回的格式
- [ ] 在 ChatLive 中添加提取图片信息的函数
- [ ] 修改消息渲染逻辑，在消息中显示图片
- [ ] 测试图片显示功能

## 执行记录

### 阶段一：分析 tool_results 数据结构

- **时间**：20251221
- **操作**：
  - 查看了 `tool_results` 的数据结构（`{:array, Ash.Type.Map}`）
  - 了解了 `search_photos` tool 返回的数据格式
  - 确认 `content` 字段被转换为字符串（通过 `LangChain.Message.ContentPart.content_to_string`）
- **结果**：
  - `tool_results` 是一个数组，每个元素包含 `name`, `content`, `display_text` 等字段
  - `content` 字段是字符串，需要解析 JSON 来提取图片信息
- **问题**：无
- **解决方案**：无

### 阶段二：实现图片提取和显示功能

- **时间**：20251221
- **操作**：
  1. 在 `ChatLive` 中添加了 `extract_photos_from_message/1` 函数
     - 从消息的 `tool_results` 中查找 `name == "search_photos"` 的结果
     - 解析 `content` 字段（JSON 字符串）提取图片信息
  2. 添加了 `extract_photos_from_tool_result/1` 函数
     - 解析 JSON 内容，支持多种数据结构（数组、对象、嵌套结构）
  3. 添加了 `normalize_photo/1` 函数
     - 规范化图片数据，提取 `id`, `url`, `note` 字段
  4. 添加了 `render_photos/2` 函数
     - 在消息中渲染图片网格
     - 使用 `<.img>` 组件显示图片
     - 图片可点击跳转到详情页
  5. 修改了消息渲染逻辑
     - 在 `chat-bubble` 中调用 `render_photos` 显示图片
  6. 修改了消息加载逻辑
     - 在 `handle_params` 中显式选择 `tool_results` 字段（因为 `public?: false`）
  7. 修改了 PubSub 广播配置
     - 在 `publish :create` 和 `publish :upsert_response` 中包含 `tool_results`
- **结果**：
  - 代码编译通过，无 linter 错误
  - 实现了图片提取和显示功能
  - 确保消息加载和广播时包含 `tool_results`
- **问题**：
  1. `tool_results` 字段的 `public?: false`，不会被默认加载
  2. PubSub 广播时没有包含 `tool_results`
  3. LiveView 模板中不能直接使用变量，需要使用 assign
- **解决方案**：
  1. 在 `handle_params` 中显式选择 `tool_results` 字段
  2. 修改 PubSub 配置，在广播时包含 `tool_results`
  3. 在模板中使用 `<% photos = extract_photos_from_message(message) %>` 提取图片，然后传递给 `render_photos`

### 阶段三：修复 tool_call_id 缺失错误

- **时间**：20251221
- **操作**：
  1. 修复了 `message_chain` 函数中的错误
     - 当 `tool_results` 中缺少 `tool_call_id` 时，`LangChain.Message.ToolResult.new!/1` 会报错
     - 添加了过滤逻辑，只处理包含有效 `tool_call_id` 的 `tool_results`
     - 添加了键规范化逻辑，处理字符串和原子键的混合情况
- **结果**：
  - 代码编译通过，无 linter 错误
  - 修复了 `tool_call_id: can't be blank` 错误
- **问题**：
  1. 数据库中存储的 `tool_results` 可能缺少 `tool_call_id` 字段
  2. `LangChain.Message.ToolResult.new!/1` 要求 `tool_call_id` 不能为空
- **解决方案**：
  1. 在 `message_chain` 函数中过滤掉没有 `tool_call_id` 的 `tool_results`
  2. 规范化键名（处理字符串和原子键）
  3. 只有当存在有效的 `tool_results` 时才创建 `ToolResult` 消息

## 测试记录

### 代码验证

- ✅ 代码编译通过，无 linter 错误
- ✅ 图片提取函数正确处理各种数据结构
- ✅ 图片渲染函数正确使用 LiveView 组件
- ✅ 修复了 `Ash.read!` 中错误的 `stream?: true` 选项
- ✅ 修复了 LiveView 模板中变量使用的问题

### 功能测试

- ✅ 在 `/chat` 页面测试图片显示功能
- ✅ 验证图片能正确显示在消息中
- ✅ 验证图片点击跳转功能（图片包含在链接中）

### 测试方法

1. 在数据库中创建了一条包含 `tool_results` 的测试消息
2. 消息包含 `search_photos` tool 的结果，其中包含图片信息（id, url, note）
3. 刷新页面后，图片成功显示在 AI 消息气泡中

### 测试结果

- ✅ 图片成功显示在消息气泡中
- ✅ 图片显示在文本内容下方
- ✅ 图片可以点击跳转到详情页
- ✅ 图片网格布局正常（grid-cols-2 md:grid-cols-3）

## 总结

### 已完成

1. ✅ 分析了 `tool_results` 数据结构
2. ✅ 实现了图片提取功能
3. ✅ 实现了图片显示功能
4. ✅ 修改了消息渲染逻辑

### 关键代码变更

1. **lib/vmemo_web/live/chat_live.ex**：
   - 添加了 `extract_photos_from_message/1` 函数
   - 添加了 `extract_photos_from_tool_result/1` 函数
   - 添加了 `normalize_photo/1` 函数
   - 添加了 `render_photos/2` 函数
   - 修改了消息渲染逻辑，在 `chat-bubble` 中显示图片
   - 修改了 `handle_params`，显式选择 `tool_results` 字段

2. **lib/vmemo/chat/message.ex**：
   - 修改了 PubSub 配置，在广播时包含 `tool_results` 字段

3. **lib/vmemo/chat/message/changes/respond.ex**：
   - 修复了 `message_chain` 函数，处理缺少 `tool_call_id` 的 `tool_results`
   - 添加了过滤和规范化逻辑

### 下一步

- 测试在 `/chat` 中通过自然语言调用图片搜索功能，验证图片显示
- 根据实际数据格式调整解析逻辑（如果需要）

# 20251221 图片搜索 MCP Server 实现

## 任务目标

实现一个支持图片搜索功能的 MCP server，满足以下要求：

1. 可以在 `/chat` 通过自然语言调用，调用交给 LLM
2. 支持第三方 chatbot，例如 cherry-stdio

## 计划阶段

### 需求分析

- **目标**：开发一个 MCP server，提供图片搜索功能，支持自然语言调用，并与第三方聊天机器人集成
- **约束条件**：
  - 使用现有的 `ash_ai` MCP server 实现
  - 基于现有的图片搜索功能（`Vmemo.PhotoService.TsPhoto.hybird_search_photos`）
  - 需要支持用户认证和权限控制
- **验收标准**：
  - 服务器能够接收自然语言请求，调用图片搜索功能
  - 在 `/chat` 页面可以通过自然语言搜索图片
  - 支持第三方 chatbot（如 cherry-stdio）通过 MCP 协议调用

### 技术方案

1. **使用 AshAi Tools**：

   - 在 `Vmemo.Photos` domain 中添加 `AshAi` extension
   - 定义 `search_photos` tool，基于 `Photo` resource 的 `hybrid_search` action

2. **集成到 Chat**：

   - 在 `Vmemo.Chat.Message.Changes.Respond` 中添加 `search_photos` tool
   - 确保 actor（用户）正确传递

3. **MCP Server 自动暴露**：
   - `AshAi.Mcp.Dev` 已经配置在 endpoint 中
   - Tools 会自动通过 MCP 协议暴露

### 架构设计

```
用户请求 (自然语言)
  ↓
Chat LiveView (/chat)
  ↓
Message.create → Oban Trigger
  ↓
Message.Changes.Respond
  ↓
AshAi.setup_ash_ai(tools: [:search_photos])
  ↓
LLM 解析请求 → 调用 search_photos tool
  ↓
Photo.hybrid_search action
  ↓
Vmemo.PhotoService.TsPhoto.hybird_search_photos
  ↓
返回搜索结果
```

### 任务分解

- [x] 分析现有代码结构和 MCP server 实现
- [ ] 在 Vmemo.Photos domain 中添加 AshAi extension 并定义 search_photos tool
- [ ] 在 chat respond 中添加 search_photos tool
- [ ] 验证 MCP server 能够自动暴露这个 tool
- [ ] 测试在 /chat 中通过自然语言调用图片搜索功能
- [ ] 测试第三方 chatbot (cherry-stdio) 集成

## 执行记录

### 阶段一：代码分析和方案设计

- **时间**：20251221
- **操作**：
  - 分析了项目中已有的 MCP server 实现（`AshAi.Mcp.Dev`）
  - 查看了图片搜索功能的实现（`Vmemo.PhotoService.TsPhoto`）
  - 理解了 AshAi tools 的定义方式
- **结果**：明确了实现方案
- **问题**：无
- **解决方案**：无

### 阶段二：实现 search_photos tool

- **时间**：20251221
- **操作**：
  1. 在 `Vmemo.Photos.Photo` resource 中添加了 `search_photos` action
     - 支持文本查询和相似图片搜索
     - 从 context 中获取 actor，自动使用当前用户 ID
  2. 在 `Vmemo.Photos` domain 中添加了 `AshAi` extension
     - 定义了 `search_photos` tool，关联到 `Photo.search_photos` action
     - 添加了描述，帮助 LLM 理解何时使用这个 tool
  3. 在 `Vmemo.Chat.Message.Changes.Respond` 中添加了 `search_photos` tool
     - 将 `tools: []` 改为 `tools: [:search_photos]`
- **结果**：
  - Tool 定义完成
  - 通过 `AshAi.exposed_tools` 验证，tool 能够正确被发现
- **问题**：无
- **解决方案**：无

### 阶段三：验证 MCP server 暴露

- **时间**：20251221
- **操作**：
  - 验证了 `AshAi.Mcp.Dev` 在 endpoint 中的配置
  - 使用 `AshAi.exposed_tools` 验证 tool 能够被发现
- **结果**：
  - MCP server 配置正确（`/ash_ai/mcp` 路径）
  - Tool 能够被正确发现和暴露
- **问题**：无
- **解决方案**：无

## 测试记录

### 代码验证

- ✅ Tool 定义正确，能够被 `AshAi.exposed_tools` 发现
- ✅ 代码编译通过，无 linter 错误
- ✅ MCP server 配置正确

### 功能测试

待执行：

- [ ] 在 `/chat` 页面测试自然语言调用图片搜索
- [ ] 测试第三方 chatbot (cherry-stdio) 集成

### 阶段四：修复 OpenRouter 模型配置

- **时间**：20251221
- **操作**：
  - 将模型从 `openai/chatgpt-4o-latest` 改为 `openai/gpt-4o`
  - 添加了 `:model` 选项，允许后续切换模型
- **结果**：
  - 使用明确支持 tool use 的模型
  - 解决了 "No endpoints found that support tool use" 错误
- **问题**：`openai/chatgpt-4o-latest` 在 OpenRouter 上不支持 tool use
- **解决方案**：改用 `openai/gpt-4o`，明确支持函数调用功能

### 阶段五：修复 Azure OpenAI schema 验证问题

- **时间**：20251221
- **操作**：
  - 将 `search_photos` action 从 `:read` 类型改为 `:action` 类型
  - 移除了 tool 定义中的 `action_parameters`
  - 修改了 action 的实现，使用 `run` 函数而不是 `prepare`
- **结果**：
  - `:action` 类型不会自动添加 `filter`、`limit`、`offset`、`sort` 等参数
  - Tool schema 只包含我们定义的三个参数（`query`、`similar_photo_id`、`page`）
  - 避免了 Azure OpenAI 对 schema 的验证错误
- **问题**：
  1. Azure OpenAI 要求 `filter` 对象必须设置 `additionalProperties: false`，但 ash_ai 生成的 schema 缺少这个字段
  2. 使用 `action_parameters` 时，`required` 数组仍然包含 `input`，但 `properties` 中可能没有 `input`，导致 schema 验证失败
- **解决方案**：将 action 改为 `:action` 类型，这样不会自动添加 read action 特有的参数，schema 更简洁且符合 Azure OpenAI 的要求

### 阶段六：修复 action 实现细节

- **时间**：20251221
- **操作**：
  - 移除了返回类型声明（`{:array, Vmemo.Photos.Photo}` 不是有效的 Ash 类型）
  - 修复了 actor 获取方式：从 `Ash.Context.get_actor(context)` 改为 `Map.get(context, :actor)`
- **结果**：
  - Action 可以正常编译
  - Tool schema 正确生成，包含 `input` 对象，里面有 `page`, `query`, `similar_photo_id` 三个参数
  - 无 linter 错误
- **问题**：
  1. `{:array, Vmemo.Photos.Photo}` 不是有效的 Ash 类型
  2. `Ash.Context.get_actor/1` 函数不存在
- **解决方案**：
  1. 移除返回类型声明，让 `run` 函数直接返回 `{:ok, list}`
  2. 使用 `Map.get(context, :actor)` 获取 actor

## 总结

### 已完成

1. ✅ 在 `Vmemo.Photos` domain 中添加了 `AshAi` extension
2. ✅ 定义了 `search_photos` tool，基于 `Photo.search_photos` action
3. ✅ 在 chat respond 中集成了 `search_photos` tool
4. ✅ 验证了 MCP server 能够自动暴露这个 tool

### 关键代码变更

1. **lib/vmemo/photos/photo.ex**：

   - 添加了 `search_photos` action，支持从 context 获取 actor

2. **lib/vmemo/photos.ex**：

   - 添加了 `AshAi` extension
   - 定义了 `search_photos` tool

3. **lib/vmemo/chat/message/changes/respond.ex**：
   - 在 `AshAi.setup_ash_ai` 中添加了 `tools: [:search_photos]`

### 下一步

- 测试在 `/chat` 中通过自然语言调用图片搜索功能
- 测试第三方 chatbot (cherry-stdio) 集成

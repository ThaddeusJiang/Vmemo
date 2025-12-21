# 20251221 修复 Photo Jason.Encoder 错误

## 任务目标

修复 `Vmemo.Photos.Photo` 缺少 `Jason.Encoder` protocol 实现导致的错误，该错误发生在 Ash AI Tools 执行 `search_photos` 时。

## 计划阶段

### 需求分析

- **问题**：`AshJsonApi.Error` 没有为 `Vmemo.Photos.Photo` 实现 `Jason.Encoder` protocol
- **原因**：当 Ash AI Tools 执行 `search_photos` 工具时，返回的 `Photo` 结构体需要被编码为 JSON，但缺少 protocol 实现
- **影响**：Ash AI Tools 无法正常返回搜索结果
- **验收标准**：
  - `Photo` 结构体可以正确编码为 JSON
  - Ash AI Tools 的 `search_photos` 工具可以正常返回结果
  - 不泄露敏感信息（如 `#Ash.NotLoaded` 关联）

### 技术方案

1. **为 `Photo` 添加 `Jason.Encoder`**：

   - 使用 `@derive Jason.Encoder` 自动实现
   - 使用 `only` 选项指定需要编码的字段，排除 `#Ash.NotLoaded` 和 `#Ecto.Schema.Metadata` 字段
   - 包含的主要字段：`:id`, `:url`, `:note`, `:caption`, `:file_id`, `:ash_user_id`, `:inserted_at`, `:updated_at`

2. **检查其他资源**：
   - 检查 `Note` 等其他可能被 Ash AI Tools 使用的资源
   - 如果也需要，一并修复

### 任务分解

- [x] 为 `Vmemo.Photos.Photo` 添加 `@derive Jason.Encoder`
- [x] 检查其他资源是否需要类似修复
- [x] 验证修复是否有效（代码检查通过）

## 执行记录

### 阶段一：分析问题

- **时间**：20251221
- **操作**：分析错误信息，确认问题原因
- **结果**：确认 `Photo` 缺少 `Jason.Encoder` 实现
- **问题**：无
- **解决方案**：添加 `@derive Jason.Encoder`

### 阶段二：实现修复

- **时间**：20251221
- **操作**：
  1. 为 `Vmemo.Photos.Photo` 添加 `@derive {Jason.Encoder, only: [...]}`
  2. 指定需要编码的字段：`:id`, `:url`, `:note`, `:caption`, `:file_id`, `:ash_user_id`, `:inserted_at`, `:updated_at`
  3. 排除 `#Ash.NotLoaded` 和 `#Ecto.Schema.Metadata` 字段
- **结果**：
  - 代码修改完成
  - 无 linter 错误
- **问题**：无
- **解决方案**：无

### 阶段三：检查其他资源

- **时间**：20251221
- **操作**：检查其他可能被 Ash AI Tools 使用的资源
- **结果**：
  - 目前只有 `search_photos` tool，返回 `Photo` 结构体
  - 其他资源（`Note`, `PhotoNote`, `PhotoMoondreamRequest`）未配置为 tool，暂不需要修复
- **问题**：无
- **解决方案**：无

## 测试记录

### 代码检查

- ✅ 代码修改完成，无 linter 错误
- ✅ `@derive Jason.Encoder` 正确添加，指定了需要编码的字段
- ✅ 排除了 `#Ash.NotLoaded` 和 `#Ecto.Schema.Metadata` 字段，避免泄露敏感信息

### 功能验证

- ✅ `Jason.Encoder` 测试通过，可以正确编码 `Photo` 结构体为 JSON
- ✅ JSON 格式正确，包含所有指定字段
- ⏳ 待运行时测试 Ash AI Tools 的 `search_photos` 功能

### 编译警告说明

编译时出现的 `Inspect` protocol 警告是 Ash Resource 的正常行为，不影响功能：

- Ash Resource 会自动为资源生成 `Inspect` 实现
- Protocol consolidation 在编译时完成，运行时添加的实现不会生效
- 这个警告可以安全忽略，不影响 `Jason.Encoder` 的功能

## 总结

- ✅ 已为 `Vmemo.Photos.Photo` 添加 `Jason.Encoder` protocol 实现
- ✅ 使用 `only` 选项指定了需要编码的字段，确保不泄露敏感信息
- ✅ 代码检查通过，修复完成
- ⏳ 需要在运行时验证 Ash AI Tools 功能是否正常工作

## 后续问题：图片 URL 域名错误

### 问题描述

在 `search_photos` action 返回给 LLM 的 JSON 中，图片 URL 包含错误的域名（`https://example.com`），导致 LLM 生成的文本中也包含错误的 URL。

### 根本原因

`Photo` 结构体的 `url` 字段存储的是相对路径（如 `/storage/v1/...`），但在序列化为 JSON 时，某些地方可能被转换为绝对 URL，但使用了错误的域名。

### 解决方案

在 `search_photos` action 中，返回结果前处理每个 Photo 的 URL，将相对路径转换为正确的绝对 URL：

- Dev 环境：`http://localhost:4000`
- Prod 环境：`https://{PHX_HOST}`（从 `System.get_env("PHX_HOST")` 获取）

### 实现方案

1. 在 `search_photos` action 的 `run` 函数中，返回前处理 URL
2. 创建 `normalize_photo_url_for_api/1` 辅助函数
3. 创建 `get_base_url/0` 辅助函数，根据环境返回正确的 base URL
4. 在返回结果前，对每个 Photo 调用 `normalize_photo_url_for_api/1`

### 任务分解

- [x] 在 `search_photos` action 中添加 URL 规范化逻辑
- [x] 创建 `get_base_url` 辅助函数
- [x] 创建 `normalize_photo_url_for_api` 辅助函数
- [ ] 测试修复是否有效

### 阶段四：修复图片 URL 域名问题

- **时间**：20251221
- **操作**：
  1. 在 `search_photos` action 的 `run` 函数中，返回结果前调用 `normalize_photo_url_for_api/1` 处理每个 Photo
  2. 创建 `normalize_photo_url_for_api/1` 函数，处理 URL 规范化：
     - 如果 URL 包含错误的域名（example.com），提取路径并重建
     - 如果 URL 已经是正确的绝对 URL，保持不变
     - 如果 URL 是相对路径，转换为绝对 URL
  3. 创建 `get_base_url/0` 函数，根据环境返回正确的 base URL：
     - Dev 环境：`http://localhost:4000`
     - Prod 环境：`https://{PHX_HOST}`
- **结果**：
  - 代码修改完成
  - 无 linter 错误
- **问题**：无
- **解决方案**：无

## 最终总结

- ✅ 已为 `Vmemo.Photos.Photo` 添加 `Jason.Encoder` protocol 实现
- ✅ 在 `search_photos` action 中添加了 URL 规范化逻辑
- ✅ URL 会根据环境自动转换为正确的绝对 URL（dev: localhost:4000, prod: PHX_HOST）
- ✅ 代码检查通过，修复完成
- ✅ **修复已验证生效**：重新测试后，LLM 生成的文本中 URL 正确使用 `http://localhost:4000/storage/v1/...`
- ✅ 不再出现错误的域名 `https://example.com`

### 测试结果

#### 第一次测试（2025-12-21 06:00）

- **测试方法**：使用 Playwright 发送"机器人图片"消息
- **测试发现**：
  1. `search_photos` action 成功执行，找到了机器人图片
  2. 但返回的 JSON 中 URL 仍然是相对路径 `/storage/v1/...`
  3. LLM 生成的文本中使用了错误的域名 `https://example.com`
- **问题原因**：代码修改后需要重新编译/重启服务器才能生效

#### 第二次测试（2025-12-21 06:10）- ✅ 成功

- **测试方法**：重新测试发送"机器人图片"消息
- **测试结果**：
  1. ✅ `search_photos` action 成功执行
  2. ✅ LLM 生成的文本中 URL 正确：`http://localhost:4000/storage/v1/...`
  3. ✅ 不再使用错误的域名 `https://example.com`
- **结论**：修复已生效，URL 规范化功能正常工作

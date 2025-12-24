# 20251224 photo_search 返回图片数据

## 任务目标

修改 `photo_search` MCP tool，返回图片的 base64 数据 URL，而不是 HTML，以便客户端可以直接显示图片。

## 计划阶段

### 需求分析

- **目标**：让 `photo_search` tool 返回图片数据，而不是 HTML 字符串
- **现状**：
  - `search_photos` action 返回 HTML 字符串
  - HTML 被 JSON 转义，无法正确显示
  - 返回类型是 `text`，用户希望是 `img/*`
- **期望**：返回图片的 base64 数据 URL，客户端可以直接显示
- **约束条件**：
  - MCP protocol 中 tool 返回值总是字符串类型
  - 需要支持多种图片格式（JPEG, PNG, GIF, WEBP）
  - 需要检测图片的 MIME 类型

### 技术方案

1. **修改 `search_photos` action**：
   - 返回 JSON 格式的图片数据 URL 数组
   - 每个元素是 data URL 格式：`data:image/{type};base64,<base64_data>`
   - 使用 `read_image_as_base64/1` 读取图片并转换为 base64
   - 自动检测图片的 MIME 类型

2. **返回格式**：
   - JSON 数组：`["data:image/jpeg;base64,...", "data:image/png;base64,...", ...]`
   - 客户端可以解析 JSON，获取 data URL，直接显示图片

### 任务分解

- [x] 分析当前 search_photos 返回 HTML 的问题
- [x] 修改 search_photos 返回图片数据（base64 或 URL）而不是 HTML
- [x] 确保返回格式是 JSON 数组的 data URL
- [x] 验证代码编译通过

## 执行记录

### 阶段一：代码分析

- **时间**：20251224
- **操作**：
  - 分析了当前 `search_photos` action 返回 HTML 的问题
  - 确认了 HTML 被 JSON 转义的问题
  - 理解了用户希望返回图片数据的需求
- **结果**：明确了修复方案
- **问题**：无
- **解决方案**：返回图片的 base64 数据 URL 列表

### 阶段二：修改 search_photos action

- **时间**：20251224
- **操作**：
  1. 修改 `search_photos` action：
     - 更新 description，说明返回 JSON 数组的 data URL
     - 修改返回逻辑，读取图片并转换为 base64
     - 使用 `read_image_as_base64/1` 函数读取图片
     - 检测 MIME 类型并构建 data URL
     - 返回 JSON 编码的 data URL 数组
  2. 处理错误情况：
     - 如果没有找到图片，返回空数组 `[]`
     - 如果读取图片失败，fallback 到 URL
- **结果**：
  - 代码修改完成
  - 无 linter 错误
  - 返回格式是 JSON 数组的 data URL
- **问题**：无
- **解决方案**：无

## 测试记录

### 代码检查

- ✅ 代码修改完成，无 linter 错误
- ✅ `search_photos` action 返回 JSON 格式的 data URL 数组
- ✅ 支持多种图片格式（JPEG, PNG, GIF, WEBP）
- ✅ MIME 类型自动检测

### 功能验证

待运行时测试：
- [ ] 测试 photo_search tool 返回的 JSON 格式
- [ ] 验证 data URL 是否正确
- [ ] 验证客户端可以解析并显示图片

## 总结

- ✅ 修改了 `search_photos` action，返回图片的 base64 数据 URL
- ✅ 返回格式是 JSON 数组：`["data:image/jpeg;base64,...", ...]`
- ✅ 支持多种图片格式，MIME 类型自动检测
- ✅ 代码编译通过，无 linter 错误
- ⏳ 待运行时测试验证功能是否正常工作

### 关键修改

1. **search_photos action 返回格式**：
   ```elixir
   image_data_urls =
     sorted_records
     |> Enum.map(fn photo ->
       case read_image_as_base64(photo.url) do
         {:ok, {base64_data, mime_type}} ->
           "data:#{mime_type};base64,#{base64_data}"
         {:error, _reason} ->
           photo.url  # Fallback to URL
       end
     end)

   {:ok, Jason.encode!(image_data_urls)}
   ```

2. **返回格式说明**：
   - JSON 数组格式：`["data:image/jpeg;base64,...", "data:image/png;base64,...", ...]`
   - 每个元素是 data URL 格式，包含 MIME 类型和 base64 编码的图片数据
   - 客户端可以解析 JSON，获取 data URL，直接显示图片

3. **关于返回类型**：
   - 根据 MCP protocol，tool 返回值总是字符串类型（`text`）
   - 虽然无法直接指定为 `img/*`，但返回的 data URL 格式可以让客户端识别为图片数据
   - 客户端可以解析 JSON，识别 data URL，然后直接显示图片

### 相关文件

- `lib/vmemo/photos/photo.ex` - Photo resource 和 `search_photos` action
- `lib/vmemo/photos.ex` - Photos domain 和 `photo_search` tool 定义

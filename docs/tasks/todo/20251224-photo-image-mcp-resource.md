# 20251224 photo_image mcp_resource 实现

## 任务目标

添加一个新的 mcp_resource，返回图片的 base64 编码数据，mime_type 设置为 image。

## 计划阶段

### 需求分析

- **目标**：添加 `photo_image` mcp_resource，返回图片的 base64 编码数据
- **现状**：
  - 已有 `photo_url` mcp_resource（返回 URL 字符串）
  - 已有 `photo_html` mcp_resource（返回 HTML）
  - 需要添加返回图片数据的 resource
- **期望**：返回图片的 base64 编码数据，mime_type 设置为 image
- **约束条件**：
  - MCP resource actions 必须返回字符串
  - 需要支持多种图片格式（JPEG, PNG, GIF, WEBP）
  - 需要检测图片的 MIME 类型

### 技术方案

1. **创建 `get_photo_image` action**：
   - 从 photo.url 中提取文件路径
   - 读取图片文件并转换为 base64 编码
   - 检测图片的 MIME 类型
   - 返回 data URL 格式：`data:image/jpeg;base64,<base64_data>`

2. **添加 mcp_resource 配置**：
   - URI 格式：`vmemo://photo/:id/image`
   - mime_type：`image/jpeg`（默认，实际会根据文件类型动态检测）
   - 返回 data URL 格式的字符串

3. **实现 MIME 类型检测**：
   - 使用 magic bytes 检测图片格式
   - 支持 JPEG, PNG, GIF, WEBP

### 任务分解

- [x] 分析 photo.url 和 file_id 的格式，确定如何获取图片文件路径
- [x] 创建 get_photo_image action，返回图片的 base64 编码
- [x] 添加 photo_image mcp_resource，mime_type 设置为 image
- [x] 验证代码编译通过，无 linter 错误
- [x] 更新工作记录文档

## 执行记录

### 阶段一：代码分析

- **时间**：20251224
- **操作**：
  - 分析了 photo.url 的格式：`/storage/v1/{user_id}/photos/{timestamp}_{filename}`
  - 查看了现有的 `read_image_as_base64` 函数实现
  - 确认了文件路径的构建方式
- **结果**：明确了实现方案
- **问题**：无
- **解决方案**：无

### 阶段二：实现 get_photo_image action

- **时间**：20251224
- **操作**：
  1. 创建 `get_photo_image` action：
     - 类型：`:string`
     - 参数：`uri`（从 mcp_resource URI 中提取）
     - 从 URI 中提取 photo ID
     - 获取 photo 记录并规范化 URL
     - 读取图片文件并转换为 base64
     - 检测 MIME 类型
     - 返回 data URL 格式
  2. 实现 `read_image_as_base64/1` 函数：
     - 从 URL 中提取相对路径
     - 构建完整的文件路径（考虑生产环境和开发环境）
     - 读取文件并转换为 base64
     - 检测 MIME 类型
     - 返回 `{:ok, {base64_data, mime_type}}`
  3. 实现 `detect_mime_type_from_binary/1` 函数：
     - 使用 magic bytes 检测图片格式
     - 支持 JPEG, PNG, GIF, WEBP
- **结果**：
  - action 实现完成
  - 支持多种图片格式
  - MIME 类型自动检测
- **问题**：无
- **解决方案**：无

### 阶段三：添加 mcp_resource 配置

- **时间**：20251224
- **操作**：
  - 在 `Vmemo.Photos` domain 中添加 `photo_image` mcp_resource
  - URI 格式：`vmemo://photo/:id/image`
  - mime_type：`image/jpeg`
  - 描述：说明返回 data URL 格式
- **结果**：
  - mcp_resource 配置完成
  - 代码编译通过
  - 无 linter 错误
- **问题**：无
- **解决方案**：无

### 阶段四：更新 URI 提取函数

- **时间**：20251224
- **操作**：
  - 更新 `extract_photo_id_from_uri/1` 函数
  - 添加对 `image` 路径的支持
  - 正则表达式更新为：`vmemo://photo/{uuid}/(url|html|image)`
- **结果**：
  - URI 提取函数支持所有三种路径
  - 代码编译通过
- **问题**：无
- **解决方案**：无

## 测试记录

### 代码检查

- ✅ 代码修改完成，无 linter 错误
- ✅ `get_photo_image` action 正确实现
- ✅ `photo_image` mcp_resource 配置正确
- ✅ MIME 类型检测支持多种格式
- ✅ 文件路径处理正确（支持生产和开发环境）

### 功能验证

待运行时测试：
- [ ] 测试 photo_image mcp_resource 返回的图片数据
- [ ] 验证不同格式的图片（JPEG, PNG, GIF, WEBP）都能正确返回
- [ ] 验证 MIME 类型检测是否正确

## 总结

- ✅ 添加了 `get_photo_image` action，返回图片的 base64 编码数据
- ✅ 实现了 MIME 类型自动检测（支持 JPEG, PNG, GIF, WEBP）
- ✅ 添加了 `photo_image` mcp_resource，mime_type 设置为 `image/jpeg`
- ✅ 返回 data URL 格式：`data:image/jpeg;base64,<base64_data>`
- ✅ 代码编译通过，无 linter 错误
- ⏳ 待运行时测试验证功能是否正常工作

### 关键修改

1. **get_photo_image action**：
   ```elixir
   action :get_photo_image, :string do
     description "Get a photo as base64-encoded image data..."
     argument :uri, :string, allow_nil?: false
     run fn input, context ->
       # 提取 photo ID，读取文件，返回 data URL
     end
   end
   ```

2. **read_image_as_base64/1 函数**：
   - 从 URL 构建文件路径
   - 读取文件并转换为 base64
   - 检测 MIME 类型
   - 返回 `{:ok, {base64_data, mime_type}}`

3. **detect_mime_type_from_binary/1 函数**：
   - 使用 magic bytes 检测图片格式
   - 支持 JPEG, PNG, GIF, WEBP

4. **mcp_resource 配置**：
   ```elixir
   mcp_resource :photo_image, "vmemo://photo/:id/image", Vmemo.Photos.Photo, :get_photo_image,
     title: "Photo Image",
     description: "Get a photo as base64-encoded image data...",
     mime_type: "image/jpeg"
   ```

### 相关文件

- `lib/vmemo/photos/photo.ex` - Photo resource 和 `get_photo_image` action
- `lib/vmemo/photos.ex` - Photos domain 和 `photo_image` mcp_resource 定义

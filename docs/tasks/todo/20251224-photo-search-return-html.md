# 20251224 photo_search 返回 HTML 格式

## 任务目标

修改 `photo_search` MCP tool，使其返回 HTML 格式以便渲染图片，而不是返回 JSON 格式的文本。

## 计划阶段

### 需求分析

- **目标**：让 `photo_search` tool 返回 HTML 格式，包含图片渲染
- **现状**：当前返回的是 `"type": "text"`，内容是 JSON 格式的 photo 数组
- **期望**：返回 HTML 格式，包含 `<img>` 标签，可以直接渲染图片
- **约束条件**：
  - 需要保持向后兼容（如果可能）
  - HTML 需要正确转义，防止 XSS
  - 图片 URL 需要正确规范化

### 技术方案

1. **修改 `search_photos` action**：
   - 将返回类型从 JSON 数组改为 HTML 字符串
   - 使用 `render_photos_as_html/1` 函数将多个 photos 渲染为 HTML
   - 参考已有的 `get_photo_html` action 的实现方式

2. **实现 HTML 渲染函数**：
   - 创建 `render_photos_as_html/1` 函数
   - 为每个 photo 生成包含 `<img>` 标签的 HTML
   - 包含 caption 和 note（如果有）
   - 使用 `Phoenix.HTML.html_escape` 防止 XSS

3. **URL 处理**：
   - 使用已有的 `normalize_photo_url_for_api/1` 函数
   - 使用 `get_base_url/0` 获取正确的 base URL

### 任务分解

- [x] 分析当前 photo_search 的返回格式
- [x] 修改 search_photos action 返回 HTML
- [x] 实现 render_photos_as_html 函数
- [ ] 测试 photo_search tool 返回 HTML 格式

## 执行记录

### 阶段一：代码分析和方案设计

- **时间**：20251224
- **操作**：
  - 分析了 `search_photos` action 的当前实现
  - 查看了 `get_photo_html` action 的实现，作为参考
  - 确认了 `normalize_photo_url_for_api` 和 `get_base_url` 函数的存在
- **结果**：明确了实现方案
- **问题**：无
- **解决方案**：无

### 阶段二：修改 search_photos action

- **时间**：20251224
- **操作**：
  1. 修改 `search_photos` action：
     - 更新 description，说明返回 HTML 格式
     - 修改返回逻辑，当没有找到照片时返回 HTML 字符串 `"<div>No photos found.</div>"`
     - 当找到照片时，调用 `render_photos_as_html/1` 函数生成 HTML
  2. 实现 `render_photos_as_html/1` 函数：
     - 接收 photo 列表作为参数
     - 为每个 photo 生成包含 `<img>` 标签的 HTML
     - 包含 caption 和 note（如果有）
     - 使用 `Phoenix.HTML.html_escape` 转义文本内容
     - 将所有 photo 的 HTML 组合成一个 `<div class="photo-search-results">` 容器
- **结果**：
  - 代码修改完成
  - 无 linter 错误
- **问题**：无
- **解决方案**：无

## 测试记录

### 代码验证

- ✅ 代码编译通过，无 linter 错误
- ✅ HTML 转义正确，使用 `Phoenix.HTML.html_escape` 防止 XSS
- ✅ URL 规范化使用已有的函数

### 功能测试

待执行：
- [ ] 在 `/chat` 页面测试 photo_search tool 返回 HTML 格式
- [ ] 验证图片是否正确渲染
- [ ] 验证 caption 和 note 是否正确显示

## 技术细节

### 关键修改

1. **search_photos action**：
   - 返回类型：从 JSON 数组改为 HTML 字符串
   - 空结果处理：返回 `"<div>No photos found.</div>"` 而不是空数组
   - HTML 生成：调用 `render_photos_as_html/1` 函数

2. **render_photos_as_html/1 函数**：
   ```elixir
   defp render_photos_as_html(photos) when is_list(photos) do
     # 为每个 photo 生成 HTML
     # 包含 <img> 标签、caption、note
     # 使用 Phoenix.HTML.html_escape 转义
   end
   ```

3. **HTML 结构**：
   ```html
   <div class="photo-search-results">
     <div class="photo-card">
       <img src="..." alt="..." class="photo-image" />
       <div class="photo-caption">...</div>
       <div class="photo-note">...</div>
     </div>
     ...
   </div>
   ```

### 相关文件

- `lib/vmemo/photos/photo.ex` - Photo resource 和 `search_photos` action
- `lib/vmemo/photos.ex` - Photos domain 和 `photo_search` tool 定义

## 总结

- ✅ 修改了 `search_photos` action 返回 HTML 格式
- ✅ 实现了 `render_photos_as_html/1` 函数
- ✅ 代码通过 linter 检查
- ⏳ 待测试功能是否正常工作

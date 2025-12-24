# 20251224 修复 html_escape 返回 safe 元组的问题

## 任务目标

修复 `Phoenix.HTML.html_escape` 返回 `{:safe, iodata}` 元组导致 Ash 序列化失败的问题。

## 问题分析

### 错误信息

```
** (Phoenix.NotAcceptableError) protocol String.Chars not implemented for Tuple

Got value:
    {:safe, "..."}
```

### 问题原因

1. `Phoenix.HTML.html_escape` 返回的是 `{:safe, iodata}` 元组，而不是普通字符串
2. 在字符串插值中直接使用 `html_escape` 的结果时，Elixir 会尝试调用 `to_string/1`
3. `to_string/1` 无法处理 `{:safe, iodata}` 元组，导致协议错误
4. Ash 在序列化 tool 返回值时，尝试将整个返回值转换为字符串，遇到了 safe 元组

### 影响范围

- `render_photos_as_html/1` 函数：在 `search_photos` action 中使用
- `get_photo_html` action：返回单个 photo 的 HTML

## 计划阶段

### 解决方案

使用模式匹配提取 `{:safe, iodata}` 元组中的字符串部分：

```elixir
{:safe, escaped_text} = Phoenix.HTML.html_escape(text)
# 使用 escaped_text（字符串）而不是整个元组
```

### 技术方案

1. 修改 `render_photos_as_html/1` 函数：
   - 对每个 `html_escape` 调用使用模式匹配提取字符串
   - 确保所有 HTML 字符串都是普通字符串，而不是 safe 元组

2. 修改 `get_photo_html` action：
   - 同样使用模式匹配提取字符串
   - 重构代码，先提取所有转义后的字符串，再构建 HTML

## 执行记录

### 阶段一：修复 render_photos_as_html 函数

- **时间**：20251224
- **操作**：
  - 修改 `render_photos_as_html/1` 函数
  - 对 `alt_text`、`caption_html`、`note_html` 中的 `html_escape` 调用使用模式匹配
- **结果**：
  - 所有 `html_escape` 返回值都被正确提取为字符串
  - 函数现在返回普通字符串，而不是包含 safe 元组的字符串

### 阶段二：修复 get_photo_html action

- **时间**：20251224
- **操作**：
  - 修改 `get_photo_html` action 中的 HTML 生成逻辑
  - 使用模式匹配提取所有转义后的字符串
  - 重构代码，先提取字符串，再构建 HTML
- **结果**：
  - 代码更清晰，易于维护
  - 确保返回的 HTML 是普通字符串

## 测试记录

- ✅ 代码修改完成，无 linter 错误
- ✅ 所有 `html_escape` 调用都已修复
- [待实际测试] 验证 MCP tool 调用是否成功，不再出现协议错误

## 总结

- ✅ 修复了 `render_photos_as_html/1` 函数中的 `html_escape` 使用
- ✅ 修复了 `get_photo_html` action 中的 `html_escape` 使用
- ✅ 所有 HTML 转义现在都返回普通字符串，而不是 safe 元组
- ✅ 代码更清晰，易于维护

### 关键修改

1. **render_photos_as_html/1**：
   ```elixir
   {:safe, alt_text} = Phoenix.HTML.html_escape(photo.caption || photo.note || "Photo")
   {:safe, escaped_caption} = Phoenix.HTML.html_escape(photo.caption)
   {:safe, escaped_note} = Phoenix.HTML.html_escape(photo.note)
   ```

2. **get_photo_html action**：
   ```elixir
   {:safe, alt_text} = Phoenix.HTML.html_escape(normalized_photo.caption || normalized_photo.note || "Photo")
   {:safe, escaped_caption} = Phoenix.HTML.html_escape(normalized_photo.caption)
   {:safe, escaped_note} = Phoenix.HTML.html_escape(normalized_photo.note)
   ```

### 相关文件

- `lib/vmemo/photos/photo.ex` - Photo resource 和相关 actions

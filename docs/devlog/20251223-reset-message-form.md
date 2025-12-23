# 20251223 重置消息表单功能

## 任务概述

实现发送消息后自动重置表单的功能，清除输入框中的内容。

## 实现方案

### 技术方案

使用 Phoenix LiveView 的 `push_event` 机制，在服务器端发送事件，在客户端 JavaScript 中处理表单重置。

### 代码变更

#### 1. 服务器端 (`lib/vmemo_web/live/chat_live.ex`)

在 `handle_event("send_message", ...)` 的成功分支中添加 `push_event`：

```elixir
socket
|> assign_message_form()
|> stream_insert(:messages, message, at: 0)
|> push_event("reset_form", %{form_id: "message-form"})
|> then(&{:noreply, &1})
```

#### 2. 客户端 (`assets/js/app.js`)

添加全局事件监听器来处理 `phx:reset_form` 事件：

```javascript
window.addEventListener('phx:reset_form', (event) => {
  const { form_id } = event.detail
  const form = document.getElementById(form_id)
  if (form) {
    form.reset()
  }
})
```

## 技术细节

- **事件机制**：Phoenix LiveView 的 `push_event` 会在 DOM 上触发 `phx:` 前缀的自定义事件
- **表单重置**：使用原生 DOM API `form.reset()` 来重置表单
- **事件命名**：遵循项目中的命名约定，使用 `phx:reset_form` 事件名

## 参考

- 项目中的 `assets/js/hooks/focus.js` 使用了类似的全局事件监听模式
- Phoenix LiveView 文档：`push_event` 和客户端事件处理

## 测试

待用户测试验证：
1. 在消息输入框中输入文本
2. 点击发送按钮
3. 验证输入框是否被清空

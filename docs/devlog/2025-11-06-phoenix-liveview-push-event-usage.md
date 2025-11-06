# Phoenix LiveView push_event 使用范围

**项目**: Vmemo
**技术栈**: Phoenix LiveView, Elixir
**日期**: 2025-01-26

## 问题

`push_event` 是否是 LiveView 特有的？Phoenix Component 是否可以使用？

## 答案

`push_event` 是 **LiveView 特有的功能**，只能在以下上下文中使用：

### **LiveView** **LiveComponents** 可以使用 push_event

1. **LiveView** - 使用 `use YourApp, :live_view` 的模块
2. **LiveComponent** - 使用 `use YourApp, :live_component` 的模块

两者都拥有 `socket`，这是 `push_event` 工作的前提。

### Phoenix Function Component 不能使用 push_event

- **Phoenix Function Component** - 普通的函数组件（使用 `def component/1` 定义）
  - 原因：函数组件只接收 `assigns`，没有 `socket`

## 代码示例

### LiveComponent 中使用 push_event

```elixir
defmodule VmemoWeb.LiveComponents.UploadForm do
  use VmemoWeb, :live_component

  def handle_event("submit", _params, socket) do
    # ✅ 可以使用 push_event，因为这是 LiveComponent
    socket = Phoenix.LiveView.push_event(socket, "focus", %{
      selector: "#note"
    })
    {:noreply, socket}
  end
end
```

### Helper 函数封装

```elixir
defmodule VmemoWeb.Live.FocusHelpers do
  def focus(socket, id_selector, opts \\ []) do
    Phoenix.LiveView.push_event(socket, "focus", %{
      selector: id_selector,
      delay: Keyword.get(opts, :delay, 100),
      select_all: Keyword.get(opts, :select_all, false)
    })
  end
end
```

## 替代方案

如果需要在普通组件中触发客户端事件：

1. **改为 LiveComponent** - 如果组件需要在 LiveView 中使用
2. **在父 LiveView 中处理** - 通过 `assigns` 传递数据给组件
3. **使用 JavaScript hooks** - 通过 `phx-hook` 属性直接处理客户端事件

## 相关文件

- `lib/vmemo_web/live/focus_helpers.ex` - push_event 使用示例
- `lib/vmemo_web/live/components/upload_form.ex` - LiveComponent 中使用 push_event

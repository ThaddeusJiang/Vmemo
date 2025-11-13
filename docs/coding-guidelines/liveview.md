# LiveView coding guidelines

## LiveView Error Handling

Phoenix LiveView 中，handle_event 无论成功失败都应该是 `{:noreply, socket}`，通过 socket |> assign(:key, value) 才控制UI。

```elixir
# data
{:noreply, socket |> assign(:data, data)}

# error
{:noreply, socket |> assign(:error, reason)}
```

LiveView + Ecto + form

```elixir
# 模板片段：实时校验 + 提交禁用 + 错误显示
<.simple_form for={@changeset} as={:user} phx-change="validate" phx-submit="save">
  <.input field={@changeset[:email]} type="email" label="Email" />
  <.input field={@changeset[:name]} type="text" label="Name" />
  <.button phx-disable-with="保存中...">保存</.button>
</.simple_form>

# validate 事件在服务端返回带错误的 changeset 即可：
def handle_event("validate", %{"user" => params}, socket) do
  changeset =
    %User{}
    |> Accounts.change_user(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, :changeset, changeset)}
end
```

异步更新：Task + send(self) + handle_info

```elixir
def handle_event("heavy", _params, socket) do
  Task.start(fn ->
    result = do_heavy_work()
    send(self(), {:heavy_done, result})
  end)

  {:noreply, assign(socket, :loading, true)}
end

def handle_info({:heavy_done, {:ok, data}}, socket),
  do: {:noreply, socket |> assign(:data, data) |> assign(:loading, false)}

def handle_info({:heavy_done, {:error, reason}}, socket),
  do: {:noreply, socket |> put_flash(:error, inspect(reason)) |> assign(:loading, false)}
```

## LiveView Server->Client

server `push_event`, client Hook `handleEvent`

```elixir
{:noreply, socket |> push_event("toast", %{type: "error", message: "保存失败"})}
```

```js
// assets/js/app.js
let Hooks = {
  Toast: {
    mounted() {
      this.handleEvent("toast", ({ type, message }) => {
        window.toast?.show({ type, message }); // 你的前端 Toast 组件
      });
    }
  }
}

let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
liveSocket.connect();
```

```html
# 模板挂载 Hook
<div id="toast-root" phx-hook="Toast"></div>
```

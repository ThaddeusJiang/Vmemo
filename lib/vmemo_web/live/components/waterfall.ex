defmodule VmemoWeb.LiveComponents.Waterfall do
  @moduledoc false
  use VmemoWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:col, 1)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  @impl true
  def handle_event("change-col", %{"col" => col}, socket) do
    {:noreply,
     socket
     |> assign(:col, col)}
  end

  def split_list(list, n) do
    list
    |> Enum.with_index()
    |> Enum.group_by(fn {_elem, index} -> rem(index, n) end)
    |> Enum.map(fn {_key, group} -> Enum.map(group, &elem(&1, 0)) end)
  end

  attr :items, :list, default: []
  attr :class, :string, default: ""
  slot :card, required: true
  slot :empty, required: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "w-full ",
      @class || ""
    ]}>
      <%= if Enum.empty?(@items) do %>
        <%= if @empty do %>
          {render_slot(@empty)}
        <% else %>
          <div class="text-center text-gray-500 mt-4">No photos found.</div>
        <% end %>
      <% else %>
        <div id={@id} phx-hook="Resizer" phx-target={@myself} data-col={@col}>
          <div class={[
            "grid gap-3",
            case @col do
              4 -> "grid-cols-4"
              3 -> "grid-cols-3"
              2 -> "grid-cols-2"
              _ -> "hidden"
            end
          ]}>
            <div :for={items <- @items |> split_list(@col)} class="space-y-2">
              <%= for item <- items do %>
                {render_slot(@card, item)}
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end

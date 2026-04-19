defmodule VmemoWeb.LiveComponents.ConversationTitleEditor do
  @moduledoc false
  use VmemoWeb, :live_component

  alias Vmemo.Chat

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:editing, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div :if={@editing} class="flex-1 flex items-center gap-2">
        <form
          phx-submit="save"
          phx-target={@myself}
          class="flex-1 flex items-center gap-2"
        >
          <input
            type="text"
            id={"title-input-#{@id}"}
            value={@conversation.title || ""}
            phx-keydown="handle-keydown"
            phx-target={@myself}
            name="title"
            class="input input-bordered flex-1"
          />
          <button
            type="submit"
            class="btn btn-sm btn-ghost btn-circle"
            aria-label="Save"
          >
            <.icon name="hero-check-circle" class="h-4 w-4" />
          </button>
          <button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="btn btn-sm btn-ghost btn-circle"
            aria-label="Cancel"
          >
            <.icon name="hero-x-mark-solid" class="h-4 w-4" />
          </button>
        </form>
      </div>
      <div
        :if={!@editing}
        phx-click="start-edit"
        phx-target={@myself}
        class="cursor-pointer hover:opacity-70 flex-1 text-base"
      >
        {build_title_string(@conversation.title)}
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("start-edit", _params, socket) do
    socket = assign(socket, :editing, true)
    # Push event to focus and select all text after a short delay
    socket =
      Phoenix.LiveView.push_event(socket, "focus", %{
        selector: "#title-input-#{socket.assigns.id}",
        delay: 50,
        select_all: true
      })

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :editing, false)}
  end

  def handle_event("handle-keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :editing, false)}
  end

  def handle_event("handle-keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"title" => title}, socket) do
    user = socket.assigns.current_user
    conversation = socket.assigns.conversation
    trimmed_title = String.trim(title)

    # Allow empty title (will be nil in database)
    title_to_save = if trimmed_title == "", do: nil, else: trimmed_title

    case Chat.update_conversation(
           conversation,
           %{title: title_to_save},
           actor: user
         ) do
      {:ok, updated_conversation} ->
        send(self(), {:conversation_updated, updated_conversation})
        {:noreply, assign(socket, :editing, false)}

      {:error, _error} ->
        {:noreply, assign(socket, :editing, false)}
    end
  end

  def build_title_string(title) do
    cond do
      title == nil -> "Untitled conversation"
      is_binary(title) && String.length(title) > 25 -> String.slice(title, 0, 25) <> "..."
      is_binary(title) && String.length(title) <= 25 -> title
    end
  end
end

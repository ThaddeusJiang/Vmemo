defmodule VmemoWeb.LiveComponents.ConversationTitleEditor do
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
            value={@conversation.title || ""}
            phx-keydown="handle_keydown"
            phx-target={@myself}
            name="title"
            class="input input-sm input-bordered flex-1"
            autofocus
          />
          <button
            type="submit"
            class="btn btn-sm btn-ghost"
            aria-label="Save"
          >
            <.icon name="hero-check-circle" class="h-4 w-4" />
          </button>
          <button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="btn btn-sm btn-ghost"
            aria-label="Cancel"
          >
            <.icon name="hero-x-mark-solid" class="h-4 w-4" />
          </button>
        </form>
      </div>
      <div
        :if={!@editing}
        phx-click="start_edit"
        phx-target={@myself}
        class="cursor-pointer hover:opacity-70 flex-1"
      >
        {build_title_string(@conversation.title)}
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("start_edit", _params, socket) do
    {:noreply, assign(socket, :editing, true)}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :editing, false)}
  end

  def handle_event("handle_keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :editing, false)}
  end

  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"title" => title}, socket) do
    user = socket.assigns.current_ash_user
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

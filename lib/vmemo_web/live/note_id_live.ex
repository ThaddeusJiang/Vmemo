defmodule VmemoWeb.NoteIdLive do
  require Logger
  use VmemoWeb, :live_view

  alias Ash
  alias Vmemo.Memo.Note
  alias VmemoWeb.LiveComponents.NoteUpdateForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    actor = socket.assigns.current_user

    case Ash.get(Note, id, actor: actor, load: [:photos]) do
      {:ok, note} ->
        {:noreply,
         socket
         |> assign(note: note)
         |> assign(photos: note.photos || [])}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(note: nil)
         |> assign(photos: [])}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow">
      <div class="w-full max-w-screen-xl mx-auto">
        <%= if @note do %>
          <.live_component
            id="note_update_form"
            module={NoteUpdateForm}
            note={@note}
            photos={@photos}
            patch={~p"/notes/#{@note.id}"}
            current_user={@current_user}
          />
        <% else %>
          <.not_found />
        <% end %>
      </div>
    </section>
    """
  end
end

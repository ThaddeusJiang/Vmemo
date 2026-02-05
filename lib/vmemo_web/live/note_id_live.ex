defmodule VmemoWeb.NoteIdLive do
  require Logger
  use VmemoWeb, :live_view

  alias Ash
  alias Vmemo.Photos.Note
  alias VmemoWeb.LiveComponents.NoteUpdateForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    actor = socket.assigns.current_ash_user

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
    <section class="w-full mx-auto max-w-3xl p-4 sm:py-6 lg:px-8">
      <%= if @note do %>
        <.live_component
          id="note_update_form"
          module={NoteUpdateForm}
          note={@note}
          photos={@photos}
          patch={~p"/notes/#{@note.id}"}
          current_ash_user={@current_ash_user}
        />
      <% else %>
        <.not_found />
      <% end %>
    </section>
    """
  end
end

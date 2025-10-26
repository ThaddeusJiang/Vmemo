defmodule VmemoWeb.NoteIdLive do
  require Logger
  use VmemoWeb, :live_view

  alias Vmemo.PhotoService.TsNote
  alias VmemoWeb.LiveComponents.NoteUpdateForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    user_id = socket.assigns.current_ash_user.id
    {:ok, %{note: note, photos: photos}} = TsNote.get(id, :photos)

    if note == nil || note.belongs_to != Integer.to_string(user_id) do
      {:noreply,
       socket
       |> assign(note: nil)
       |> assign(photos: [])}
    else
      {:noreply,
       socket
       |> assign(note: note)
       |> assign(photos: photos)}
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
        />
      <% else %>
        <.not_found />
      <% end %>
    </section>
    """
  end
end

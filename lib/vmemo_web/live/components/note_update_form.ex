defmodule VmemoWeb.LiveComponents.NoteUpdateForm do
  @moduledoc false
  use VmemoWeb, :live_component

  alias Ash
  alias Vmemo.Memo.Note
  alias VmemoWeb.LiveComponents.Waterfall

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(%{
         "note" => assigns.note.text
       })
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-submit="save" phx-target={@myself} class="flex flex-col space-y-2">
      <.live_component id="photos" module={Waterfall} items={@photos}>
        <:card :let={photo}>
          <.link navigate={~p"/photos/#{photo.id}"}>
            <.img src={photo.url} alt={photo.note} />
          </.link>
        </:card>
      </.live_component>

      <div class="flex flex-col space-y-1">
        <.textarea_field
          id={@form[:note].id}
          name={@form[:note].name}
          value={@form[:note].value}
          label="Note"
          errors={@form[:note].errors}
        />
      </div>

      <div class="flex items-center justify-between">
        <.button>Save</.button>
        <.button
          type="button"
          variant="danger"
          data-confirm="You can't undo this action. Are you sure?"
          phx-click="delete-note"
          phx-value-id={@note.id}
          phx-target={@myself}
        >
          Delete
        </.button>
      </div>
    </form>
    """
  end

  @impl true
  def handle_event("save", %{"note" => note_text}, socket) do
    actor = socket.assigns.current_user

    case Ash.update(socket.assigns.note, %{text: note_text}, actor: actor, load: [:photos]) do
      {:ok, note} ->
        {:noreply,
         socket
         |> assign(note: note, photos: note.photos || [])
         |> assign(form: to_form(%{"note" => note.text}))
         |> put_flash(:info, "Updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete-note", _params, socket) do
    actor = socket.assigns.current_user

    case Note.destroy(socket.assigns.note, actor: actor) do
      {:ok, _note} ->
        {:noreply, socket |> put_flash(:info, "Deleted") |> push_navigate(to: ~p"/home")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

defmodule VmemoWeb.LiveComponents.NoteUpdateForm do
  use VmemoWeb, :live_component

  alias VmemoWeb.LiveComponents.Waterfall

  alias Vmemo.PhotoService.TsNote

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
          phx-click="delete_note"
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
    # user_id = socket.assigns.current_user.id
    note_id = socket.assigns.note.id
    now = :os.system_time(:millisecond)

    TsNote.update(%{
      id: note_id,
      text: note_text,
      updated_at: now
    })

    {:noreply, socket |> put_flash(:info, "Updated") |> push_patch(to: socket.assigns.patch)}
  end

  @impl true
  def handle_event("delete_note", %{"id" => id}, socket) do
    TsNote.delete(id)

    {:noreply, socket |> put_flash(:info, "Deleted") |> push_navigate(to: ~p"/home")}
  end
end

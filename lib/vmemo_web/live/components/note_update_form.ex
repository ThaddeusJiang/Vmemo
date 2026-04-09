defmodule VmemoWeb.LiveComponents.NoteUpdateForm do
  @moduledoc false
  use VmemoWeb, :live_component

  alias Ash
  alias Vmemo.Memo.Note
  alias VmemoWeb.LiveComponents.PhotoCard
  alias VmemoWeb.LiveComponents.Waterfall

  @impl true
  def update(assigns, socket) do
    note_text = assigns.note.text

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:note_dirty, false)
     |> assign(:original_note_text, note_text)
     |> assign_new(:form, fn ->
       to_form(%{
        "note" => note_text
       })
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-submit="save" phx-change="validate" phx-target={@myself} class="flex flex-col space-y-2">
      <section class="h-1/3 min-h-0 flex flex-col overflow-hidden">
        <.live_component
          id="photos"
          module={Waterfall}
          items={@photos}
          class="flex-1 min-h-0 overflow-y-auto pr-1"
        >
          <:card :let={photo}>
            <PhotoCard.photo_card photo={photo} />
          </:card>
        </.live_component>
      </section>

      <div class="form-control w-full">
        <div class="space-y-1">
          <div class="flex items-center justify-between">
            <.label for={@form[:note].id} class="label-text">Note</.label>
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-ghost btn-square btn-sm" aria-label="Open note actions">
                <.icon name="hero-ellipsis-vertical" class="h-4 w-4" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow-lg border border-base-300"
              >
                <li>
                  <button
                    type="button"
                    class="text-error"
                    data-confirm="You can't undo this action. Are you sure?"
                    phx-click="delete-note"
                    phx-value-id={@note.id}
                    phx-target={@myself}
                  >
                    Delete
                  </button>
                </li>
              </ul>
            </div>
          </div>
          <.textarea
            id={@form[:note].id}
            name={@form[:note].name}
            value={@form[:note].value}
          />
        </div>
        <.error :for={msg <- @form[:note].errors}>
          <span class="label-text-alt text-error">{msg}</span>
        </.error>
      </div>

      <div class="mt-2 flex items-center justify-end gap-2">
        <.button :if={@note_dirty}>
          <span class="inline-flex items-center gap-2 phx-submit-loading:hidden">
            Save
          </span>
          <span class="hidden items-center gap-2 phx-submit-loading:inline-flex">
            <.icon name="hero-arrow-path" class="size-4 animate-spin" />
            Saving...
          </span>
        </.button>
      </div>
    </form>
    """
  end

  @impl true
  def handle_event("validate", %{"note" => note_text}, socket) do
    note_dirty = note_text != socket.assigns.original_note_text

    {:noreply,
     socket
     |> assign(:note_dirty, note_dirty)
     |> assign(:form, to_form(%{"note" => note_text}))}
  end

  @impl true
  def handle_event("save", %{"note" => note_text}, socket) do
    actor = socket.assigns.current_user

    case Ash.update(socket.assigns.note, %{text: note_text}, actor: actor, load: [:photos]) do
      {:ok, note} ->
        {:noreply,
         socket
         |> assign(note: note, photos: note.photos || [])
         |> assign(:note_dirty, false)
         |> assign(:original_note_text, note.text)
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

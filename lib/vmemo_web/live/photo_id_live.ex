defmodule VmemoWeb.PhotoIdLive do
  require Logger
  use Gettext, backend: VmemoWeb.Gettext

  use VmemoWeb, :live_view

  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.PhotoMoondreamRequest

  alias VmemoWeb.LiveComponents.Waterfall
  alias VmemoWeb.LiveComponents.MoondreamPanel

  @impl true
  def mount(%{"id" => id, "action" => _action}, _session, socket) do
    mount_photo(id, socket)
  end

  def mount(%{"id" => id}, _session, socket) do
    mount_photo(id, socket)
  end

  defp mount_photo(id, socket) do
    user = socket.assigns.current_ash_user

    case Photo.get_with_notes(id, user.id, actor: user) do
      {:ok, photo} ->
        notes = photo.notes || []

        case Photo.list_similar(photo.id, user.id, actor: user) do
          {:ok, photos} ->
            # Load moondream requests
            moondream_requests =
              case PhotoMoondreamRequest.list_by_photo(photo.id, actor: user) do
                {:ok, requests} -> requests
                _ -> []
              end

            socket =
              socket
              |> assign(photo: photo)
              |> assign(notes: notes)
              |> assign(show_expanded: false)
              |> assign(photos: photos)
              |> assign(moondream_requests: moondream_requests)
              |> assign(moondream_loading_requests: MapSet.new())
              |> assign_new(:form, fn ->
                to_form(%{
                  "note" => photo.note,
                  "caption" => photo.caption
                })
              end)

            # Subscribe to PubSub
            if connected?(socket) do
              Phoenix.PubSub.subscribe(Vmemo.PubSub, "photo_moondream_request:#{photo.id}")
            end

            {:ok, socket}

          _ ->
            {:ok,
             socket
             |> assign(photo: nil)
             |> assign(notes: [])}
        end

      _ ->
        {:ok,
         socket
         |> assign(photo: nil)
         |> assign(notes: [])}
    end
  end

  @impl true
  def handle_event("delete-photo", %{"id" => id}, socket) do
    user = socket.assigns.current_ash_user

    case Ash.get(Photo, id, actor: user) do
      {:ok, photo} ->
        Photo.destroy(photo, actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Deleted")
         |> push_navigate(to: ~p"/photos")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Photo not found")}
    end
  end

  @impl true
  def handle_event("save", %{"note" => note, "caption" => caption}, socket) do
    user = socket.assigns.current_ash_user

    case Photo.update(socket.assigns.photo, %{note: note, caption: caption}, actor: user) do
      {:ok, updated_photo} ->
        {:noreply,
         socket
         |> assign(:photo, updated_photo)
         |> assign(
           :form,
           to_form(%{
             "note" => updated_photo.note,
             "caption" => updated_photo.caption
           })
         )
         |> put_flash(:info, "Saved")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save")}
    end
  end

  @impl true
  def handle_event("gen-description", _, socket) do
    user = socket.assigns.current_ash_user

    case Photo.gen_description(socket.assigns.photo, actor: user) do
      {:ok, updated_photo} ->
        {:noreply,
         socket
         |> assign(:photo, updated_photo)
         |> assign(
           :form,
           to_form(%{
             "note" => updated_photo.note,
             "caption" => updated_photo.caption
           })
         )
         |> put_flash(:info, "Caption generated")}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to generate caption: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("show-expanded", _, socket) do
    {:noreply, socket |> assign(show_expanded: true)}
  end

  @impl true
  def handle_event("hide-expanded", _, socket) do
    {:noreply, socket |> assign(show_expanded: false)}
  end

  @impl true
  def handle_info({:moondream_request_updated, payload}, socket) do
    user = socket.assigns.current_ash_user

    moondream_requests =
      case PhotoMoondreamRequest.list_by_photo(socket.assigns.photo.id, actor: user) do
        {:ok, requests} -> requests
        _ -> socket.assigns.moondream_requests
      end

    loading_requests =
      socket.assigns.moondream_loading_requests
      |> MapSet.delete(payload.request_id)

    send_update(MoondreamPanel,
      id: "moondream-panel",
      requests: moondream_requests,
      loading_requests: loading_requests
    )

    {:noreply,
     socket
     |> assign(moondream_requests: moondream_requests)
     |> assign(moondream_loading_requests: loading_requests)}
  end

  @impl true
  def handle_info({:moondream_request_submitted, request}, socket) do
    user = socket.assigns.current_ash_user

    moondream_requests =
      case PhotoMoondreamRequest.list_by_photo(socket.assigns.photo.id, actor: user) do
        {:ok, requests} -> requests
        _ -> socket.assigns.moondream_requests
      end

    loading_requests = MapSet.put(socket.assigns.moondream_loading_requests, request.id)

    {:noreply,
     socket
     |> assign(moondream_requests: moondream_requests)
     |> assign(moondream_loading_requests: loading_requests)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 sm:p-4 lg:p-4">
      <%= if @photo == nil do %>
        <.not_found />
      <% else %>
        <div class=" flex flex-col space-y-6 w-full mx-auto max-w-screen-lg">
          <div class=" gap-2 space-y-2 sm:grid sm:grid-cols-2 sm:space-y-0 max-h-[60%] ">
            <div class="space-y-2 flex flex-col justify-center relative">
              <figure class="w-auto h-auto group relative">
                <%!-- <figcaption class="text-lg font-semibold text-gray-900">
                  <%= @photo.note %>
                </figcaption> --%>

                <%= if @photo.caption && @photo.caption != "" do %>
                  <.button
                    variant="outline"
                    class=" absolute top-2 left-2 btn-circle text-green-500"
                    aria-label={gettext("Regenerate caption")}
                    phx-click="gen-description"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="24"
                      height="24"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      class="lucide lucide-brain-circuit w-4 h-4 inline "
                    >
                      <path d="M12 5a3 3 0 1 0-5.997.125 4 4 0 0 0-2.526 5.77 4 4 0 0 0 .556 6.588A4 4 0 1 0 12 18Z" /><path d="M9 13a4.5 4.5 0 0 0 3-4" /><path d="M6.003 5.125A3 3 0 0 0 6.401 6.5" /><path d="M3.477 10.896a4 4 0 0 1 .585-.396" /><path d="M6 18a4 4 0 0 1-1.967-.516" /><path d="M12 13h4" /><path d="M12 18h6a2 2 0 0 1 2 2v1" /><path d="M12 8h8" /><path d="M16 8V5a2 2 0 0 1 2-2" /><circle
                        cx="16"
                        cy="13"
                        r=".5"
                      /><circle cx="18" cy="3" r=".5" /><circle cx="20" cy="21" r=".5" /><circle
                        cx="20"
                        cy="8"
                        r=".5"
                      />
                    </svg>
                  </.button>
                <% else %>
                  <.button
                    variant="outline"
                    class=" absolute top-2 left-2 btn-circle btn-icon"
                    aria-label={gettext("Generate caption")}
                    phx-click="gen-description"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="24"
                      height="24"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      class="lucide lucide-brain-circuit w-4 h-4 inline "
                    >
                      <path d="M12 5a3 3 0 1 0-5.997.125 4 4 0 0 0-2.526 5.77 4 4 0 0 0 .556 6.588A4 4 0 1 0 12 18Z" /><path d="M9 13a4.5 4.5 0 0 0 3-4" /><path d="M6.003 5.125A3 3 0 0 0 6.401 6.5" /><path d="M3.477 10.896a4 4 0 0 1 .585-.396" /><path d="M6 18a4 4 0 0 1-1.967-.516" /><path d="M12 13h4" /><path d="M12 18h6a2 2 0 0 1 2 2v1" /><path d="M12 8h8" /><path d="M16 8V5a2 2 0 0 1 2-2" /><circle
                        cx="16"
                        cy="13"
                        r=".5"
                      /><circle cx="18" cy="3" r=".5" /><circle cx="20" cy="21" r=".5" /><circle
                        cx="20"
                        cy="8"
                        r=".5"
                      />
                    </svg>
                  </.button>
                <% end %>

                <.img src={@photo.url} alt={@photo.note} />

                <.link
                  href={@photo.url}
                  class="absolute bottom-2 right-2 btn btn-circle hidden group-hover:flex sm:group-hover:hidden items-center justify-center group-hover:bg-base-100"
                  aria-label={gettext("expand")}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    class="size-4"
                  >
                    <path d="M6.41421 5H10V3H3V10H5V6.41421L9.29289 10.7071L10.7071 9.29289L6.41421 5ZM21 14H19V17.5858L14.7071 13.2929L13.2929 14.7071L17.5858 19H14V21H21V14Z">
                    </path>
                  </svg>
                </.link>

                <.button
                  variant="outline"
                  phx-click="show-expanded"
                  aria-label={gettext("expand")}
                  class="absolute bottom-2 right-2 btn-circle hidden group-hover:hidden sm:group-hover:flex items-center justify-center group-hover:bg-base-100"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    class="h-4 w-4"
                  >
                    <path d="M6.41421 5H10V3H3V10H5V6.41421L9.29289 10.7071L10.7071 9.29289L6.41421 5ZM21 14H19V17.5858L14.7071 13.2929L13.2929 14.7071L17.5858 19H14V21H21V14Z">
                    </path>
                  </svg>
                </.button>
              </figure>

              <div class="grow" />
            </div>

            <.simple_form
              for={@form}
              phx-submit="save"
              class="w-full flex flex-col gap-4"
            >
              <.textarea_field
                id={@form[:note].id}
                name={@form[:note].name}
                value={@form[:note].value}
                label="Note"
              />

              <.textarea_field
                id={@form[:caption].id}
                name={@form[:caption].name}
                value={@form[:caption].value}
                label="Caption"
              />

              <:actions>
                <div class="flex items-center justify-between w-full">
                  <.button>Save</.button>
                  <.button
                    variant="danger"
                    phx-click="delete-photo"
                    phx-value-id={@photo.id}
                    data-confirm="You can't undo this action. Are you sure?"
                    aria-label={gettext("delete")}
                    class="btn-square"
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </.button>
                </div>
              </:actions>
            </.simple_form>
          </div>

          <.live_component
            id="moondream-panel"
            module={MoondreamPanel}
            photo={@photo}
            current_user={@current_ash_user}
            requests={@moondream_requests}
            loading_requests={@moondream_loading_requests}
          />

          <div class="grid gap-4 grid-cols-4">
            <div class="space-y-2 col-span-4 sm:col-span-3 lg:col-span-2">
              <h2 class="text-lg font-semibold">
                Similar photos({length(@photos)})
              </h2>

              <.live_component id="similar-photos" module={Waterfall} items={@photos}>
                <:card :let={photo}>
                  <.link navigate={~p"/photos/#{photo.id}"} class="link link-hover block">
                    <.img src={photo.url} alt={photo.note} />
                  </.link>
                </:card>
              </.live_component>
            </div>

            <div class="space-y-2 col-span-4 sm:col-span-1 lg:col-span-2">
              <h2 class="text-lg font-semibold ">
                References({length(@notes)})
              </h2>

              <div class="space-y-2">
                <.link
                  :for={note <- @notes}
                  navigate={~p"/notes/#{note.id}"}
                  class="link link-hover block"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="size-4 inline-block"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M13.19 8.688a4.5 4.5 0 0 1 1.242 7.244l-4.5 4.5a4.5 4.5 0 0 1-6.364-6.364l1.757-1.757m13.35-.622 1.757-1.757a4.5 4.5 0 0 0-6.364-6.364l-4.5 4.5a4.5 4.5 0 0 0 1.242 7.244"
                    />
                  </svg>

                  <span>{note.text |> String.split("\n") |> hd()}</span>
                </.link>
              </div>
            </div>
          </div>
        </div>

        <.modal :if={@show_expanded} id="expanded_photo" show on_cancel={JS.push("hide-expanded")}>
          <.img src={@photo.url} alt={@photo.note} />
        </.modal>
      <% end %>
    </div>
    """
  end
end

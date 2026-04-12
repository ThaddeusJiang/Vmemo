defmodule VmemoWeb.ImageIdLive do
  require Logger
  use Gettext, backend: VmemoWeb.Gettext

  use VmemoWeb, :live_view

  alias Vmemo.Ai.VisionRequest
  alias Vmemo.Memo.Image

  alias VmemoWeb.LiveComponents.MoondreamPanel
  alias VmemoWeb.LiveComponents.Waterfall

  @impl true
  def mount(%{"id" => id, "action" => _action}, _session, socket) do
    mount_photo(id, socket)
  end

  def mount(%{"id" => id}, _session, socket) do
    mount_photo(id, socket)
  end

  defp mount_photo(id, socket) do
    user = socket.assigns.current_user

    with {:ok, image} <- Image.get_with_notes(id, user.id, actor: user),
         {:ok, images} <- Image.list_similar(image.id, user.id, actor: user) do
      {:ok, assign_loaded_photo(socket, user, image, images)}
    else
      _ -> {:ok, assign_photo_not_found(socket)}
    end
  end

  @impl true
  def handle_event("delete-image", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Ash.get(Image, id, actor: user) do
      {:ok, image} ->
        Image.destroy(image, actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Deleted")
         |> push_navigate(to: ~p"/images")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Image not found")}
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    user = socket.assigns.current_user
    note = Map.get(params, "note", socket.assigns.image.note)
    caption = Map.get(params, "caption", socket.assigns.image.caption)

    case Image.update(socket.assigns.image, %{note: note, caption: caption}, actor: user) do
      {:ok, updated_photo} ->
        original_form_values = %{"note" => updated_photo.note, "caption" => updated_photo.caption}

        {:noreply,
         socket
         |> assign(:image, updated_photo)
         |> assign(:form_dirty, false)
         |> assign(:original_form_values, original_form_values)
         |> assign(
           :form,
           to_form(original_form_values)
         )
         |> put_flash(:info, "Saved")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save")}
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    note = Map.get(params, "note", socket.assigns.form[:note].value || "")
    caption = Map.get(params, "caption", socket.assigns.form[:caption].value || "")
    form_values = %{"note" => note, "caption" => caption}
    form_dirty = form_values != socket.assigns.original_form_values

    {:noreply,
     socket
     |> assign(:form_dirty, form_dirty)
     |> assign(:form, to_form(form_values))}
  end

  @impl true
  def handle_event("gen-description", _, socket) do
    user = socket.assigns.current_user
    image = socket.assigns.image

    case VisionRequest.create_caption(%{image_id: image.id, user_id: user.id}, actor: user) do
      {:ok, request} ->
        loading_requests = MapSet.put(socket.assigns.caption_loading_requests, request.id)

        # Update requests list
        updated_requests = [request | socket.assigns.caption_requests]

        latest_caption_request =
          updated_requests
          |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
          |> List.first()

        {:noreply,
         socket
         |> assign(:caption_loading_requests, loading_requests)
         |> assign(:caption_requests, updated_requests)
         |> assign(:latest_caption_request, latest_caption_request)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create caption request")}
    end
  end

  @impl true
  def handle_event("retry-caption-request", %{"request_id" => request_id}, socket) do
    user = socket.assigns.current_user

    with {:ok, request} <- Ash.get(VisionRequest, request_id, actor: user),
         true <- request.status == "failed",
         {:ok, updated_request} <- VisionRequest.retry(request, %{}, actor: user) do
      updated_requests =
        reset_caption_request_status(socket.assigns.caption_requests, updated_request.id)

      latest_caption_request = latest_caption_request_from(updated_requests)
      loading_requests = MapSet.put(socket.assigns.caption_loading_requests, updated_request.id)

      {:noreply,
       socket
       |> assign(:caption_loading_requests, loading_requests)
       |> assign(:caption_requests, updated_requests)
       |> assign(:latest_caption_request, latest_caption_request)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update-search-engine", _, socket) do
    user = socket.assigns.current_user
    image = socket.assigns.image

    case Image.update_search_engine(image, %{}, actor: user) do
      {:ok, updated_photo} ->
        {:noreply,
         socket
         |> assign(:image, updated_photo)
         |> put_flash(:info, "Retrying Typesense sync")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to retry Typesense sync")}
    end
  end

  @impl true
  def handle_event("generate-caption", _, socket) do
    user = socket.assigns.current_user
    image = socket.assigns.image

    case Image.request_generate_caption(image, %{}, actor: user) do
      {:ok, updated_photo} ->
        {:noreply,
         socket
         |> assign(:image, updated_photo)
         |> put_flash(:info, "Retrying caption generation")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to retry caption generation")}
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
  def handle_info({:vision_request_updated, payload}, socket) do
    user = socket.assigns.current_user

    vision_requests =
      case VisionRequest.list_by_image(socket.assigns.image.id, actor: user) do
        {:ok, requests} -> requests
        _ -> socket.assigns.moondream_requests
      end

    moondream_requests = vision_requests
    caption_requests = caption_requests_from(vision_requests)

    latest_caption_request =
      caption_requests
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> List.first()

    loading_requests =
      socket.assigns.caption_loading_requests
      |> MapSet.delete(payload.request_id)

    moondream_loading_requests =
      socket.assigns.moondream_loading_requests
      |> MapSet.delete(payload.request_id)

    send_update(MoondreamPanel,
      id: "moondream-panel",
      requests: moondream_requests,
      loading_requests: moondream_loading_requests
    )

    # Update image if caption was generated
    socket =
      if payload.status == "completed" && payload.function_type == "caption" do
        case Image.get_with_notes(socket.assigns.image.id, user.id, actor: user) do
          {:ok, updated_photo} ->
            current_note = socket.assigns.form[:note].value || updated_photo.note

            socket
            |> assign(:image, updated_photo)
            |> assign(
              :form,
              to_form(%{
                "note" => current_note,
                "caption" => updated_photo.caption
              })
            )
            |> put_flash(:info, "Caption generated")

          _ ->
            socket
        end
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:moondream_requests, moondream_requests)
     |> assign(:moondream_loading_requests, moondream_loading_requests)
     |> assign(:caption_requests, caption_requests)
     |> assign(:caption_loading_requests, loading_requests)
     |> assign(:latest_caption_request, latest_caption_request)}
  end

  @impl true
  def handle_info({:moondream_request_submitted, request}, socket) do
    user = socket.assigns.current_user

    moondream_requests =
      case VisionRequest.list_by_image(socket.assigns.image.id, actor: user) do
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
      <%= if @image == nil do %>
        <.not_found />
      <% else %>
        <div class=" flex flex-col space-y-6 w-full mx-auto max-w-screen-xl">
          <div class=" gap-2 space-y-2 sm:grid sm:grid-cols-2 sm:space-y-0 max-h-[60%] ">
            <div class="space-y-2 flex flex-col items-center justify-center relative min-h-[400px]">
              <figure class="w-auto h-auto group relative">
                <%!-- <figcaption class="text-lg font-semibold text-gray-900">
                  <%= @image.note %>
                </figcaption> --%>

                <.img
                  src={@image.url}
                  alt={@image.note}
                  class="block !w-auto !max-w-full !h-auto !max-h-[400px] mx-auto !object-contain rounded-lg shadow hover:shadow-lg transition-shadow"
                />

                <.link
                  href={@image.url}
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
                  class="absolute top-2 right-2 btn-circle hidden group-hover:hidden sm:group-hover:flex items-center justify-center group-hover:bg-base-100"
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
            </div>

            <div class="relative">
              <div class="dropdown dropdown-end absolute top-0 right-0 z-10">
                <div tabindex="0" role="button" class="btn btn-ghost btn-square btn-sm">
                  <.icon name="hero-ellipsis-vertical" class="h-4 w-4" />
                </div>
                <ul
                  tabindex="0"
                  class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow-lg border border-base-300"
                >
                  <li>
                    <button
                      type="button"
                      phx-click="gen-description"
                      disabled={
                        if @latest_caption_request,
                          do:
                            @latest_caption_request.status == "pending" ||
                              @latest_caption_request.status == "processing",
                          else: false
                      }
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
                        class={
                          "lucide lucide-brain-circuit h-4 w-4 " <>
                            if(@image.caption && @image.caption != "",
                              do: "text-green-500",
                              else: "text-base-content"
                            )
                        }
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
                      <span>
                        {if @image.caption && @image.caption != "",
                          do: gettext("Regenerate caption"),
                          else: gettext("Generate caption")}
                      </span>
                    </button>
                  </li>
                  <li class="border-t border-base-300 my-1"></li>
                  <li>
                    <button
                      type="button"
                      phx-click="update-search-engine"
                      disabled={
                        @image.typesense_status == "pending" or
                          @image.typesense_status == "processing"
                      }
                    >
                      <.icon name="hero-arrow-path" class="h-4 w-4" />
                      <span>
                        {gettext("Retry Typesense sync")} ({@image.typesense_status})
                      </span>
                    </button>
                  </li>
                  <li>
                    <button
                      type="button"
                      phx-click="generate-caption"
                      disabled={
                        @image.moondream_status == "pending" or
                          @image.moondream_status == "processing"
                      }
                    >
                      <.icon name="hero-arrow-path" class="h-4 w-4" />
                      <span>
                        {gettext("Retry Moondream caption")} ({@image.moondream_status})
                      </span>
                    </button>
                  </li>
                  <li class="border-t border-base-300 my-1"></li>
                  <li>
                    <button
                      type="button"
                      phx-click="delete-image"
                      phx-value-id={@image.id}
                      data-confirm="You can't undo this action. Are you sure?"
                    >
                      <.icon name="hero-trash" class="h-4 w-4 text-error" />
                      <span>{gettext("Delete")}</span>
                    </button>
                  </li>
                </ul>
              </div>

              <.simple_form
                for={@form}
                phx-submit="save"
                phx-change="validate"
                class="w-full flex flex-col pt-2"
              >
                <.textarea_field
                  id={@form[:note].id}
                  name={@form[:note].name}
                  value={@form[:note].value}
                  label="Note"
                />

                <div class="form-control w-full">
                  <div class="space-y-1">
                    <div class="flex items-center gap-2">
                      <.label for={@form[:caption].id}>Caption</.label>
                      <%= if @latest_caption_request do %>
                        <%= if @latest_caption_request.status == "pending" || @latest_caption_request.status == "processing" do %>
                          <span class="text-sm text-success animate-pulse">thinking</span>
                        <% end %>
                        <%= if @latest_caption_request.status == "failed" && @latest_caption_request.error_message do %>
                          <div class="text-sm text-error space-y-2">
                            <div>
                              <span class="font-medium">Error:</span> {format_error_message(
                                @latest_caption_request.error_message
                              )}
                            </div>
                            <div>
                              <.button
                                variant="outline"
                                size="sm"
                                phx-click="retry-caption-request"
                                phx-value-request_id={@latest_caption_request.id}
                              >
                                Retry
                              </.button>
                            </div>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                    <textarea
                      id={@form[:caption].id}
                      name={@form[:caption].name}
                      class={[
                        "textarea textarea-bordered w-full rounded-lg",
                        if(@latest_caption_request,
                          do:
                            @latest_caption_request.status == "pending" ||
                              @latest_caption_request.status == "processing",
                          else: false
                        ) && "animate-pulse"
                      ]}
                      disabled={
                        if @latest_caption_request,
                          do:
                            @latest_caption_request.status == "pending" ||
                              @latest_caption_request.status == "processing",
                          else: false
                      }
                    >{Phoenix.HTML.Form.normalize_value("textarea", @form[:caption].value)}</textarea>
                  </div>
                  <.error :for={msg <- @form[:caption].errors}>
                    {msg}
                  </.error>
                </div>

                <:actions>
                  <.button :if={@form_dirty}>
                    <span class="inline-flex items-center gap-2 phx-submit-loading:hidden">
                      Save
                    </span>
                    <span class="hidden items-center gap-2 phx-submit-loading:inline-flex">
                      <.icon name="hero-arrow-path" class="size-4 animate-spin" /> Saving...
                    </span>
                  </.button>
                </:actions>
              </.simple_form>
            </div>
          </div>

          <.live_component
            id="moondream-panel"
            module={MoondreamPanel}
            image={@image}
            current_user={@current_user}
            requests={@moondream_requests}
            loading_requests={@moondream_loading_requests}
          />

          <div :if={length(@images) > 0 || length(@notes) > 0} class="grid gap-4 grid-cols-4">
            <div :if={length(@images) > 0} class="space-y-2 col-span-4 sm:col-span-3 lg:col-span-2">
              <h2 class="text-lg font-semibold">
                Similar images ({length(@images)})
              </h2>

              <.live_component id="similar-images" module={Waterfall} items={@images}>
                <:card :let={image}>
                  <.link navigate={~p"/images/#{image.id}"} class="link link-hover block">
                    <.img src={image.url} alt={image.note} />
                  </.link>
                </:card>
              </.live_component>
            </div>

            <div :if={length(@notes) > 0} class="space-y-2 col-span-4 sm:col-span-1 lg:col-span-2">
              <h2 class="text-lg font-semibold ">
                Notes ({length(@notes)})
              </h2>

              <div class="space-y-2">
                <.link
                  :for={note <- @notes}
                  navigate={~p"/notes/#{note.id}"}
                  class="inline-flex items-center gap-1"
                >
                  <.icon name="hero-document-text" class="size-4 shrink-0" />
                  <span class="hover:underline">{note.text |> String.split("\n") |> hd()}</span>
                </.link>
              </div>
            </div>
          </div>
        </div>

        <div
          :if={@show_expanded}
          id="expanded_photo"
          data-cancel={JS.push("hide-expanded")}
          class="relative z-50"
        >
          <div
            id="expanded_photo-bg"
            class="bg-zinc-800/90 fixed inset-0 transition-opacity"
            aria-hidden="true"
          />
          <div
            class="fixed inset-0"
            role="dialog"
            aria-modal="true"
            tabindex="0"
            aria-labelledby="expanded_photo-title"
            aria-describedby="expanded_photo-description"
          >
            <div class="h-full max-h-screen flex items-center justify-center">
              <.focus_wrap
                id="expanded_photo-container"
                phx-window-keydown={JS.exec("data-cancel", to: "#expanded_photo")}
                phx-key="escape"
                phx-click-away={JS.exec("data-cancel", to: "#expanded_photo")}
                class="bg-transparent rounded-none shadow-none relative overflow-visible"
              >
                <.button
                  phx-click={JS.exec("data-cancel", to: "#expanded_photo")}
                  class="fixed top-4 right-4 z-[60] btn-circle bg-white text-black hover:bg-white border border-zinc-200 !shadow-none"
                  aria-label="close"
                >
                  <.icon name="hero-x-mark-solid" class="h-4 w-4" />
                </.button>

                <div id="expanded_photo-content" class="flex items-center justify-center">
                  <.img
                    src={@image.url}
                    alt={@image.note}
                    class="!w-auto !h-auto max-w-[calc(100vw-4rem)] max-h-[calc(100vh-4rem)] rounded-md !shadow-none hover:!shadow-none block"
                    id="expanded_photo-image"
                  />
                </div>
              </.focus_wrap>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_error_message(error_message) when is_binary(error_message) do
    error_message
  end

  defp format_error_message(_), do: "Unknown error"

  defp assign_loaded_photo(socket, user, image, images) do
    vision_requests = list_vision_requests(image.id, user)
    caption_requests = caption_requests_from(vision_requests)
    latest_caption_request = latest_caption_request_from(caption_requests)
    original_form_values = %{"note" => image.note, "caption" => image.caption}

    socket
    |> assign(image: image)
    |> assign(notes: image.notes || [])
    |> assign(show_expanded: false)
    |> assign(images: images)
    |> assign(moondream_requests: vision_requests)
    |> assign(moondream_loading_requests: MapSet.new())
    |> assign(caption_requests: caption_requests)
    |> assign(caption_loading_requests: MapSet.new())
    |> assign(latest_caption_request: latest_caption_request)
    |> assign(form_dirty: false)
    |> assign(original_form_values: original_form_values)
    |> assign_new(:form, fn ->
      to_form(original_form_values)
    end)
    |> maybe_subscribe_vision_request(image.id)
  end

  defp assign_photo_not_found(socket) do
    socket
    |> assign(image: nil)
    |> assign(notes: [])
  end

  defp list_vision_requests(image_id, user) do
    case VisionRequest.list_by_image(image_id, actor: user) do
      {:ok, requests} -> requests
      _ -> []
    end
  end

  defp maybe_subscribe_vision_request(socket, image_id) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vmemo.PubSub, "vision_request:#{image_id}")
    end

    socket
  end

  defp latest_caption_request_from(caption_requests) do
    caption_requests
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> List.first()
  end

  defp reset_caption_request_status(caption_requests, request_id) do
    Enum.map(caption_requests, fn req ->
      if req.id == request_id do
        Map.merge(req, %{status: "pending", error_message: nil})
      else
        req
      end
    end)
  end

  defp caption_requests_from(requests) do
    Enum.filter(requests, &(&1.function_type == "caption"))
  end
end

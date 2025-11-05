defmodule VmemoWeb.HomePageLive do
  require Logger

  use VmemoWeb, :live_view

  alias Vmemo.PhotoService
  alias Vmemo.Photos.Photo

  alias VmemoWeb.LiveComponents.Waterfall
  alias VmemoWeb.LiveComponents.UploadForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_by_photo, nil)
     |> assign(show_expanded: false)
     |> allow_upload(:photo,
       accept: ~w(.png .jpg .jpeg .gif .webp),
       progress: &handle_progress/3,
       auto_upload: true,
       max_entries: 1
     )}
  end

  @impl true
  def handle_event("show_expanded", _, socket) do
    {:noreply, socket |> assign(show_expanded: true)}
  end

  @impl true
  def handle_event("hide_extened", _, socket) do
    {:noreply, socket |> assign(show_expanded: false)}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    user = socket.assigns.current_ash_user
    q = socket.assigns.q

    page = socket.assigns.page + 1
    more_photos = load_photos(q, page, user)

    {:noreply,
     socket
     |> update(:photos, &(&1 ++ more_photos))
     |> assign(:page, page)}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_by_photo", _, socket) do
    {:noreply, socket}
  end

  defp handle_progress(:photo, entry, socket) do
    user_id = socket.assigns.current_ash_user.id

    if entry.done? do
      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} = _meta ->
          filename = entry.uuid <> Path.extname(entry.client_name)

          {:ok, dest} = PhotoService.cp_file(path, socket.assigns.current_ash_user.id, filename)

          case Photo.create_with_sync(
                 %{
                   # store only file path; skip inline base64 to avoid DB encoding issues
                   image: nil,
                   note: "",
                   url: Path.join("/", dest),
                   file_id: filename,
                   user_id: user_id
                 },
                 actor: socket.assigns.current_ash_user
               ) do
            {:ok, photo} -> {:ok, {:ok, photo}}
            {:error, reason} -> {:ok, {:error, reason}}
          end
        end)

      case result do
        {:ok, {:ok, photo}} ->
          {:noreply,
           socket |> push_navigate(to: ~p"/photos/#{photo.id}?action=search", replace: true)}

        {:ok, {:error, reason}} ->
          {:noreply, socket |> put_flash(:error, "Failed to upload photo: #{inspect(reason)}")}

        other ->
          {:noreply, socket |> put_flash(:error, "Unexpected upload result: #{inspect(other)}")}
      end
    else
      {:noreply, socket}
    end
  end

  defp load_photos(q, page, user) do
    case Photo.hybrid_search(q, nil, user.id, page, actor: user) do
      {:ok, photos} -> photos
      _ -> []
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_ash_user

    q = Map.get(params, "q", "")

    photos = load_photos(q, 1, user)

    Logger.info(
      "HomePageLive handle_params: user_id=#{user.id} (#{inspect(user.id)}), q=#{q}, photos_count=#{length(photos)}"
    )

    {:noreply,
     socket
     |> assign(:photos, photos)
     |> assign(:page, 1)
     |> assign(:q, q)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow">
      <%= if @q == "" && Enum.empty?(@photos) do %>
        <div class="flex flex-col items-center justify-center min-h-[calc(100vh-200px)] gap-8">
          <div class="flex flex-col items-center gap-6 w-full max-w-2xl px-4">
            <img src={~p"/images/logo.svg"} class="h-24 w-24" alt="Vmemo Logo" />

            <form action="/home" method="get" class="w-full max-w-xl">
              <label class="input input-bordered flex items-center rounded-3xl w-full shadow-lg">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="size-5 opacity-70"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
                  />
                </svg>
                <input
                  type="search"
                  name="q"
                  class="grow ml-2"
                  placeholder="Just anything..."
                  autofocus
                />
              </label>
            </form>

            <p class="text-sm text-gray-500">Add idea or files</p>

            <div class="flex flex-wrap gap-3 justify-center">
              <button class="btn btn-outline btn-sm rounded-full">写周报</button>
              <button class="btn btn-outline btn-sm rounded-full">文案润色</button>
              <button class="btn btn-outline btn-sm rounded-full">提炼日程</button>
              <button class="btn btn-outline btn-sm rounded-full">写文章</button>
            </div>
          </div>
        </div>
      <% else %>
        <div class="flex flex-col gap-4 w-full max-w-screen-lg mx-auto">
          <.live_component id="waterfall-photos" module={Waterfall} items={@photos}>
            <:empty>
              <.live_component id="upload-form" module={UploadForm} current_user={@current_ash_user} />
            </:empty>

            <:card :let={photo}>
              <.link navigate={~p"/photos/#{photo.id}"} class="link link-hover block">
                <.img src={photo.url} alt={photo.note} id={photo.id} />
              </.link>
            </:card>
          </.live_component>

          <div phx-hook="InfiniteScroll" id="infinite-scroll"></div>
        </div>
      <% end %>
    </section>
    """
  end
end

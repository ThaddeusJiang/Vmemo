defmodule VmemoWeb.HomePageLive do
  require Logger

  alias SmallSdk.FileSystem
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
    user = socket.assigns.current_user
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
    user_id = socket.assigns.current_user.id

    if entry.done? do
      uploaded_file =
        consume_uploaded_entry(socket, entry, fn %{path: path} = _meta ->
          filename = entry.uuid <> Path.extname(entry.client_name)

          {:ok, dest} = PhotoService.cp_file(path, socket.assigns.current_user.id, filename)

          image_base64 = FileSystem.read_image_base64(dest)

          if image_base64 == nil do
            {:error, "Failed to read image file"}
          else
            {:ok, photo} =
              Photo.create_with_sync(%{
                image: image_base64,
                note: "",
                url: Path.join("/", dest),
                file_id: filename,
                user_id: Integer.to_string(user_id)
              }, actor: socket.assigns.current_user)

            {:ok, photo}
          end
        end)

      photo_id = if is_map(uploaded_file), do: uploaded_file.id, else: nil

      {:noreply,
       socket |> push_navigate(to: ~p"/photos/#{photo_id}?action=search", replace: true)}
    else
      {:noreply, socket}
    end
  end

  defp load_photos(q, page, user) do
    case Photo.hybrid_search(q, nil, Integer.to_string(user.id), page, actor: user) do
      {:ok, photos} -> photos
      _ -> []
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_user

    q = Map.get(params, "q", "")

    photos = load_photos(q, 1, user)

    Logger.info("HomePageLive handle_params: user_id=#{user.id} (#{inspect(user.id)}), q=#{q}, photos_count=#{length(photos)}")

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
      <div class="flex flex-col gap-4 w-full max-w-screen-lg mx-auto">
        <.live_component id="waterfall-photos" module={Waterfall} items={@photos}>
          <:empty>
            <.live_component id="upload-form" module={UploadForm} current_user={@current_user} />
          </:empty>

          <:card :let={photo}>
            <.link navigate={~p"/photos/#{photo.id}"} class="link link-hover block">
              <.img src={photo.url} alt={photo.note} id={photo.id} />
            </.link>
          </:card>
        </.live_component>

        <div phx-hook="InfiniteScroll" id="infinite-scroll"></div>
      </div>
    </section>
    """
  end
end

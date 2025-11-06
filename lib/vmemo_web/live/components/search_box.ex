defmodule VmemoWeb.LiveComponents.SearchBox do
  use VmemoWeb, :live_component

  alias Vmemo.PhotoService
  alias Vmemo.Photos.Photo
  # alias removed: SmallSdk.FileSystem

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(show_expanded: false)
     |> assign(:q, "")
     |> allow_upload(:photo,
       accept: ~w(.png .jpg .jpeg .gif .webp),
       progress: &handle_progress/3,
       auto_upload: true,
       max_entries: 1
     )}
  end

  @impl true
  def update(assigns, socket) do
    q = Map.get(assigns, :q, "")
    prev_show_expanded = Map.get(socket.assigns, :show_expanded, false)

    result_socket =
      socket
      |> assign(assigns)
      |> assign(:q, q)
      |> assign(:show_expanded, prev_show_expanded)

    {:ok, result_socket}
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
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_by_photo", _, socket) do
    {:noreply, socket}
  end

  defp handle_progress(:photo, entry, socket) do
    require Logger
    current_user = Map.get(socket.assigns, :current_ash_user) || Map.get(socket.assigns, :current_user)

    if is_nil(current_user) do
      {:noreply, socket}
    else
      user_id = current_user.id

      if entry.done? do
        Logger.info("Photo upload completed: #{entry.client_name}")

        photo =
          consume_uploaded_entry(socket, entry, fn %{path: path} = _meta ->
            filename = entry.uuid <> Path.extname(entry.client_name)

            {:ok, dest} = PhotoService.cp_file(path, current_user.id, filename)

            case Photo.create_immediate(
                   %{
                     note: "",
                     url: Path.join("/", dest),
                     file_id: filename,
                     user_id: user_id
                   },
                   actor: current_user
                 ) do
              {:ok, photo} ->
                Logger.info("Photo created in DB: #{photo.id}")

                case sync_photo_to_typesense(photo) do
                  {:ok, _} ->
                    Logger.info("Photo synced to Typesense: #{photo.id}")
                  {:error, reason} ->
                    Logger.error("Failed to sync to Typesense: #{inspect(reason)}")
                end

                {:ok, photo}

              {:error, reason} ->
                Logger.error("Failed to create photo: #{inspect(reason)}")
                {:error, reason}
            end
          end)

        Logger.info("Navigating to photos page with similar_photo_id=#{photo.id}")
        {:noreply, socket |> push_navigate(to: ~p"/photos?similar_photo_id=#{photo.id}", replace: true)}
      else
        {:noreply, socket}
      end
    end
  end

  defp sync_photo_to_typesense(photo) do
    require Logger
    alias Vmemo.PhotoService.TsPhoto

    inserted_at_unix = DateTime.to_unix(photo.inserted_at)

    base_data = %{
      id: photo.id,
      note: photo.note || "",
      note_ids: [],
      url: photo.url,
      file_id: photo.file_id,
      inserted_at: inserted_at_unix,
      inserted_by: photo.user_id
    }

    typesense_data =
      case read_image_as_base64(photo.url) do
        {:ok, image} ->
          Map.put(base_data, :image, image)

        {:error, reason} ->
          Logger.warning("Failed to read image for photo #{photo.id}: #{inspect(reason)}")
          base_data
      end

    case TsPhoto.get_photo(photo.id) do
      nil -> TsPhoto.create(typesense_data)
      _existing -> TsPhoto.update_photo(typesense_data)
    end
  end

  defp read_image_as_base64(url) do
    relative_path =
      url
      |> String.trim_leading("/")
      |> String.trim_leading("storage/v1/")

    file_path =
      if Mix.env() == :prod do
        Path.join([Application.app_dir(:vmemo, "priv"), "storage", "v1", relative_path])
      else
        Path.join(["storage", "v1", relative_path])
      end

    case File.read(file_path) do
      {:ok, binary} -> {:ok, Base.encode64(binary)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grow container max-w-md dropdown dropdown-open place-self-start">
      <form :if={!@show_expanded} action="/photos" method="get" class="form-control container">
        <label class="input input-bordered flex items-center rounded-3xl w-full">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-6 text-gray-400"
          >
            <circle cx="11" cy="11" r="8"></circle>
            <path d="m21 21-4.35-4.35"></path>
          </svg>
          <input type="search" name="q" class="grow" placeholder="Search" value={@q} />

          <div class="flex items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-6 hover:cursor-pointer hover:opacity-80"
              phx-click="show_expanded"
              phx-target={@myself}
              tabIndex={0}
              role="button"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7.5 3.75H6A2.25 2.25 0 0 0 3.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0 1 20.25 6v1.5m0 9V18A2.25 2.25 0 0 1 18 20.25h-1.5m-9 0H6A2.25 2.25 0 0 1 3.75 18v-1.5M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"
              />
            </svg>
          </div>
        </label>
        <%!-- TODO: search when typing --%>
      </form>

      <div
        :if={@show_expanded}
        class=" dropdown-content bg-base-100 z-10 shadow flex flex-col gap-2 relative border border-base-300 rounded-lg p-4 sm:p-4  container aspect-3/2 "
      >
        <header class="container flex items-center justify-center ">
          <p class="text-gray-500 text-sm">Search by photo</p>
          <.button
            variant="ghost"
            phx-click="hide_extened"
            phx-target={@myself}
            class="btn-circle absolute top-2 right-2"
          >
            &times;
          </.button>
        </header>
        <form
          id="search-by-photo"
          class="form-control flex flex-col items-center justify-center gap-4 flex-1"
          phx-submit="search_by_photo"
          phx-change="validate"
          phx-target={@myself}
          phx-hook="ClipboardMediaFetcher"
        >
          <label for={@uploads.photo.ref} class="text-center w-full h-full flex flex-col justify-center items-center cursor-pointer">
            <div class=" w-full h-full flex flex-col justify-center items-center">
              <img src="/images/undraw_images.svg" alt="Upload photos" class="h-20 w-auto" />
            </div>
            <div class="text-xs text-gray-500 mt-4">
              Drop an image or <span class="link">click here</span>
            </div>

            <.live_file_input upload={@uploads.photo} class="hidden" />
          </label>
        </form>
      </div>
    </div>
    """
  end
end

defmodule VmemoWeb.LiveComponents.SearchBox do
  use VmemoWeb, :live_component

  alias Vmemo.PhotoService
  alias Vmemo.Photos.Photo

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(show_expanded: false)
     |> assign(:q, "")
     |> allow_upload(:photo,
       accept: ~w(.png .jpg .jpeg .gif .webp),
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
  def handle_event("show-expanded", _, socket) do
    {:noreply, socket |> assign(show_expanded: true)}
  end

  @impl true
  def handle_event("hide-expanded", _, socket) do
    socket =
      socket.assigns.uploads.photo.entries
      |> Enum.reduce(socket, fn entry, acc ->
        cancel_upload(acc, :photo, entry.ref)
      end)
      |> assign(show_expanded: false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  @impl true
  def handle_event("validate", _, socket) do
    entries = socket.assigns.uploads.photo.entries

    socket =
      if length(entries) > 1 do
        # Keep only the first entry, cancel the rest
        entries
        |> Enum.drop(1)
        |> Enum.reduce(socket, fn entry, acc ->
          cancel_upload(acc, :photo, entry.ref)
        end)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("change-col", %{"col" => _col}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search-by-photo", _, socket) do
    current_user =
      Map.get(socket.assigns, :current_user) || Map.get(socket.assigns, :current_user)

    if is_nil(current_user) do
      {:noreply, socket}
    else
      case uploaded_entries(socket, :photo) do
        {[_ | _] = entries, []} ->
          handle_uploaded_photos(entries, socket, current_user)

        {[], []} ->
          {:noreply, socket |> put_flash(:error, "Please wait for upload to complete")}

        {[], [_ | _] = errors} ->
          error_msg = "Upload failed: #{inspect(errors)}"
          {:noreply, socket |> put_flash(:error, error_msg)}
      end
    end
  end

  defp handle_uploaded_photos(entries, socket, current_user) do
    require Logger

    results =
      for entry <- entries do
        consume_uploaded_entry(socket, entry, fn %{path: path} = _meta ->
          filename = entry.uuid <> Path.extname(entry.client_name)

          {:ok, dest} = PhotoService.cp_file(path, current_user.id, filename)

          case Photo.create_with_sync(
                 %{
                   note: "",
                   url: Path.join("/", dest),
                   file_id: filename,
                   user_id: current_user.id
                 },
                 actor: current_user
               ) do
            {:ok, photo} ->
              {:ok, photo}

            {:error, reason} ->
              Logger.error("Failed to create photo: #{inspect(reason)}")
              {:error, reason}
          end
        end)
      end

    results =
      results
      |> Enum.map(fn
        %Vmemo.Photos.Photo{} = photo -> {:ok, photo}
        {:error, reason} -> {:error, reason}
        other -> {:error, inspect(other)}
      end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        case Enum.find(results, fn result -> match?({:ok, _}, result) end) do
          {:ok, photo} ->
            {:noreply,
             socket |> push_navigate(to: ~p"/photos?similar_photo_id=#{photo.id}", replace: true)}

          _ ->
            {:noreply, socket |> put_flash(:error, "No photo created")}
        end

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Upload failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grow container dropdown dropdown-open place-self-start">
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
              phx-click="show-expanded"
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
      </form>

      <div
        :if={@show_expanded}
        class=" dropdown-content bg-base-100 z-10 shadow flex flex-col gap-2 relative border border-base-300 rounded-lg p-4 sm:p-4  container aspect-3/2 "
      >
        <header class="container flex items-center justify-center ">
          <p class="text-gray-500 text-sm">Search by photo</p>
          <.button
            variant="ghost"
            phx-click="hide-expanded"
            phx-target={@myself}
            class="btn-circle absolute top-2 right-2"
          >
            &times;
          </.button>
        </header>
        <form
          id="search-by-photo"
          class="form-control flex flex-col items-center justify-center gap-4 flex-1"
          phx-submit="search-by-photo"
          phx-change="validate"
          phx-target={@myself}
          phx-hook="ClipboardMediaFetcher"
          phx-drop-target={@uploads.photo.ref}
        >
          <%!-- Always include the file input --%>
          <.live_file_input upload={@uploads.photo} class="hidden" />

          <%= if Enum.any?(@uploads.photo.entries) do %>
            <div class="w-full flex flex-col items-center gap-4 flex-1">
              <%= for entry <- @uploads.photo.entries do %>
                <article class="upload-entry relative w-full max-w-xs aspect-square">
                  <figure class="w-full h-full">
                    <.live_img_preview entry={entry} class="w-full h-full object-cover rounded-lg" />
                  </figure>

                  <%= case entry.progress do %>
                    <% 0 -> %>
                    <% 100 -> %>
                      <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm bg-black bg-opacity-30 rounded-lg">
                        <div
                          class="radial-progress text-white"
                          style="--value:100; --size:2rem; --thickness: 2px;"
                          role="progressbar"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            stroke-width="2"
                            class="size-6"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="m4.5 12.75 6 6 9-13.5"
                            />
                          </svg>
                        </div>
                      </div>
                    <% _ -> %>
                      <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm bg-black bg-opacity-30 rounded-lg">
                        <div
                          class="radial-progress text-white"
                          style={"--value:#{entry.progress}; --size:2rem; --thickness: 2px;"}
                          role="progressbar"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke-width="2"
                            stroke="currentColor"
                            class="size-6"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="m4.5 12.75 6 6 9-13.5"
                            />
                          </svg>
                        </div>
                      </div>
                  <% end %>
                </article>
              <% end %>

              <div class="flex gap-2 mt-auto">
                <.button
                  type="submit"
                  variant="submit"
                  disabled={
                    Enum.any?(@uploads.photo.entries, fn entry ->
                      entry.progress > 0 and entry.progress < 100
                    end)
                  }
                >
                  <%= if Enum.any?(@uploads.photo.entries, fn entry -> entry.progress > 0 and entry.progress < 100 end) do %>
                    Uploading...
                  <% else %>
                    Search
                  <% end %>
                </.button>
              </div>
            </div>
          <% else %>
            <label
              for={@uploads.photo.ref}
              class="text-center w-full h-full flex flex-col justify-center items-center cursor-pointer"
            >
              <div class=" w-full h-full flex flex-col justify-center items-center">
                <img src="/images/undraw_images.svg" alt="Upload photos" class="h-20 w-auto" />
              </div>
              <div class="text-xs text-gray-500 mt-4">
                Drop an image or <span class="link">click here</span>
              </div>
            </label>
          <% end %>
        </form>
      </div>
    </div>
    """
  end
end

defmodule VmemoWeb.LiveComponents.SearchBox do
  @moduledoc false
  use VmemoWeb, :live_component

  alias Vmemo.Memo.Image

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(show_expanded: false)
     |> assign(:q, "")
     |> allow_upload(:image,
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
      socket.assigns.uploads.image.entries
      |> Enum.reduce(socket, fn entry, acc ->
        cancel_upload(acc, :image, entry.ref)
      end)
      |> assign(show_expanded: false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-image", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  @impl true
  def handle_event("validate", _, socket) do
    entries = socket.assigns.uploads.image.entries

    # max_entries is 1, but ClipboardMediaFetcher can merge multiple files in one change.
    socket =
      if length(entries) > 1 do
        entries
        |> Enum.drop(1)
        |> Enum.reduce(socket, fn entry, acc ->
          cancel_upload(acc, :image, entry.ref)
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
  def handle_event("search-by-image", _, socket) do
    current_user = Map.get(socket.assigns, :current_user)

    if is_nil(current_user) do
      {:noreply, socket}
    else
      case uploaded_entries(socket, :image) do
        {completed, []} ->
          case completed do
            [entry] ->
              consume_one_photo_for_search(entry, socket, current_user)

            [] ->
              {:noreply, socket |> put_flash(:error, "Please wait for upload to complete")}

            _ ->
              {:noreply,
               socket
               |> put_flash(
                 :error,
                 "Search by image uses exactly one image. Remove extra files and try again."
               )}
          end

        {_completed, errors} ->
          error_msg = "Upload failed: #{inspect(errors)}"
          {:noreply, socket |> put_flash(:error, error_msg)}
      end
    end
  end

  defp consume_one_photo_for_search(entry, socket, current_user) do
    require Logger

    result =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        filename = entry.uuid <> Path.extname(entry.client_name)

        case Image.ingest_temp_file_for_similarity_search(path, filename, actor: current_user) do
          {:ok, image_id} ->
            {:ok, image_id}

          {:error, reason} ->
            Logger.error("search-by-image failed: #{inspect(reason)}")
            {:ok, {:error, reason}}
        end
      end)

    # consume_uploaded_entry/3 returns the *unwrapped* value from {:ok, value} (see Phoenix LiveView upload_channel).
    case result do
      image_id when is_binary(image_id) ->
        {:noreply,
         socket
         |> push_navigate(to: ~p"/images?similar_image_id=#{image_id}", replace: true)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Search index is not ready or upload failed. Please try again."
         )}

      other ->
        {:noreply, socket |> put_flash(:error, "Search by image failed: #{inspect(other)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grow container dropdown dropdown-open place-self-start">
      <form :if={!@show_expanded} action="/images" method="get" class="form-control container">
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
          <p class="text-gray-500 text-sm">Search by image</p>
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
          id="search-by-image"
          class="form-control flex flex-col items-center justify-center gap-4 flex-1"
          phx-submit="search-by-image"
          phx-change="validate"
          phx-target={@myself}
          phx-hook="ClipboardMediaFetcher"
          phx-drop-target={@uploads.image.ref}
        >
          <%!-- Always include the file input --%>
          <.live_file_input upload={@uploads.image} class="hidden" />

          <%= if Enum.any?(@uploads.image.entries) do %>
            <div class="w-full flex flex-col items-center gap-4 flex-1">
              <%= for entry <- @uploads.image.entries do %>
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
                    Enum.any?(@uploads.image.entries, fn entry ->
                      entry.progress > 0 and entry.progress < 100
                    end)
                  }
                >
                  <%= if Enum.any?(@uploads.image.entries, fn entry -> entry.progress > 0 and entry.progress < 100 end) do %>
                    Uploading...
                  <% else %>
                    Search
                  <% end %>
                </.button>
              </div>
            </div>
          <% else %>
            <label
              for={@uploads.image.ref}
              class="text-center w-full h-full flex flex-col justify-center items-center cursor-pointer"
            >
              <div class=" w-full h-full flex flex-col justify-center items-center">
                <img src="/images/undraw_images.svg" alt="Upload images" class="h-20 w-auto" />
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

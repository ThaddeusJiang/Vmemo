defmodule VmemoWeb.LiveComponents.SearchBox do
  @moduledoc false
  use VmemoWeb, :live_component
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageStorage

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:q, "")
     |> assign(:submit_error, nil)
     |> allow_upload(:image,
       accept: ~w(.png .jpg .jpeg .gif .webp),
       max_entries: 100,
       max_file_size: 12_000_000
     )}
  end

  @impl true
  def update(assigns, socket) do
    q = Map.get(assigns, :q, "")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:q, q)}
  end

  @impl true
  def handle_event("cancel-image", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, assign(socket, :submit_error, nil)}
  end

  @impl true
  def handle_event("change-col", %{"col" => _col}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("image-action", %{"intent" => intent}, socket) do
    case {Map.get(socket.assigns, :current_user), intent} do
      {nil, _} ->
        {:noreply, socket}

      {current_user, "search"} ->
        handle_search_by_image(socket, current_user)

      {current_user, "upload-only"} ->
        handle_upload_only(socket, current_user)

      {_current_user, _other} ->
        {:noreply, assign(socket, :submit_error, gettext("Unknown image action."))}
    end
  end

  defp handle_search_by_image(socket, current_user) do
    case uploaded_entries(socket, :image) do
      {completed, []} ->
        handle_completed_upload_entries(socket, current_user, completed, :search)

      {_completed, errors} ->
        error_msg = "Upload failed: #{inspect(errors)}"
        {:noreply, assign(socket, :submit_error, error_msg)}
    end
  end

  defp handle_upload_only(socket, current_user) do
    case uploaded_entries(socket, :image) do
      {completed, []} ->
        handle_completed_upload_entries(socket, current_user, completed, :upload_only)

      {_completed, errors} ->
        error_msg = "Upload failed: #{inspect(errors)}"
        {:noreply, assign(socket, :submit_error, error_msg)}
    end
  end

  defp handle_completed_upload_entries(socket, current_user, [entry], :search) do
    consume_one_photo_for_search(entry, socket, current_user)
  end

  defp handle_completed_upload_entries(socket, current_user, [entry], :upload_only) do
    consume_one_photo_for_upload_only(entry, socket, current_user)
  end

  defp handle_completed_upload_entries(socket, current_user, entries, :upload_only)
       when is_list(entries) do
    consume_photos_for_upload_only(socket, current_user, entries)
  end

  defp handle_completed_upload_entries(socket, _current_user, [], _mode) do
    {:noreply, assign(socket, :submit_error, gettext("Upload is still in progress."))}
  end

  defp handle_completed_upload_entries(socket, _current_user, _entries, _mode) do
    {:noreply,
     assign(
       socket,
       :submit_error,
       gettext("Use exactly one image for search. Remove extra files.")
     )}
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
         assign(
           socket,
           :submit_error,
           gettext("Search failed: index unavailable or upload failed.")
         )}

      other ->
        {:noreply,
         assign(
           socket,
           :submit_error,
           gettext("Search by image failed: %{reason}", reason: inspect(other))
         )}
    end
  end

  defp consume_one_photo_for_upload_only(entry, socket, current_user) do
    require Logger

    result =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        filename = entry.uuid <> Path.extname(entry.client_name)

        with {:ok, dest} <- ImageStorage.cp_file(path, current_user.id, filename),
             {:ok, image} <-
               Image.create_with_sync(
                 %{
                   note: "",
                   url: Path.join("/", dest),
                   file_id: filename,
                   user_id: current_user.id,
                   upload_batch_id: Ecto.UUID.generate(),
                   inner_purpose: nil
                 },
                 actor: current_user
               ) do
          {:ok, image.id}
        else
          {:error, reason} ->
            Logger.error("upload-only failed: #{inspect(reason)}")
            {:ok, {:error, reason}}
        end
      end)

    case result do
      image_id when is_binary(image_id) ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Image uploaded successfully."))
         |> push_navigate(to: ~p"/images/#{image_id}", replace: true)}

      {:error, _reason} ->
        {:noreply,
         assign(
           socket,
           :submit_error,
           gettext("Upload failed. Please retry.")
         )}

      other ->
        {:noreply,
         assign(
           socket,
           :submit_error,
           gettext("Upload failed: %{reason}", reason: inspect(other))
         )}
    end
  end

  defp consume_photos_for_upload_only(socket, current_user, entries) do
    results =
      Enum.map(entries, fn entry ->
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          filename = entry.uuid <> Path.extname(entry.client_name)

          with {:ok, dest} <- ImageStorage.cp_file(path, current_user.id, filename),
               {:ok, image} <-
                 Image.create_with_sync(
                   %{
                     note: "",
                     url: Path.join("/", dest),
                     file_id: filename,
                     user_id: current_user.id,
                     upload_batch_id: Ecto.UUID.generate(),
                     inner_purpose: nil
                   },
                   actor: current_user
                 ) do
            {:ok, image.id}
          else
            {:error, reason} ->
              {:ok, {:error, reason}}
          end
        end)
      end)

    success_ids =
      results
      |> Enum.filter(&is_binary/1)

    failed_count = length(results) - length(success_ids)

    case {success_ids, failed_count} do
      {[], _} ->
        {:noreply, assign(socket, :submit_error, gettext("Upload failed. Please retry."))}

      {ids, 0} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("%{count} images uploaded successfully.", count: length(ids))
         )
         |> push_navigate(to: ~p"/images", replace: true)}

      {ids, _failed} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("%{count} images uploaded successfully.", count: length(ids))
         )
         |> assign(
           :submit_error,
           gettext("Some images failed to upload. Please retry failed ones.")
         )
         |> push_navigate(to: ~p"/images", replace: true)}
    end
  end

  @impl true
  def render(assigns) do
    entries = assigns.uploads.image.entries
    has_image = Enum.any?(entries)
    single_image = length(entries) == 1
    uploading = Enum.any?(entries, fn entry -> entry.progress > 0 and entry.progress < 100 end)

    has_upload_errors =
      upload_errors(assigns.uploads.image) != [] or
        Enum.any?(entries, fn entry -> upload_errors(assigns.uploads.image, entry) != [] end)

    assigns =
      assigns
      |> assign(:has_image, has_image)
      |> assign(:single_image, single_image)
      |> assign(:uploading, uploading)
      |> assign(:can_search_image, single_image and not uploading and not has_upload_errors)

    ~H"""
    <div class="w-full max-w-2xl flex flex-col gap-3">
      <form :if={!@has_image} action="/images" method="get" class="form-control w-full">
        <label class="input input-bordered search-shell-input flex items-center rounded-xl w-full h-12">
          <.icon name="hero-magnifying-glass" class="size-6 text-base-content/45" />
          <input
            id={"#{@id}-text-search-input"}
            type="search"
            name="q"
            class="grow"
            placeholder="Search"
            value={@q}
            disabled={@has_image}
            enterkeyhint="search"
            inputmode="search"
            phx-hook="SearchSubmitOnEnter"
          />
        </label>
      </form>

      <form
        id="search-by-image"
        class={[
          "form-control relative flex flex-col items-center justify-center gap-4 border rounded-xl p-4 min-h-[18rem] bg-base-100/80 transition-all duration-200",
          "border-base-300 hover:border-primary/40 hover:shadow-[0_14px_36px_-20px_color-mix(in_oklch,var(--color-base-content)_35%,transparent)]",
          !@has_image && "cursor-pointer"
        ]}
        phx-submit="image-action"
        phx-change="validate"
        phx-target={@myself}
        phx-hook="ClipboardMediaFetcher"
        phx-drop-target={@uploads.image.ref}
        data-click-upload-area="true"
      >
        <.error :if={@submit_error != nil}>
          {@submit_error}
        </.error>

        <.error :for={err <- upload_errors(@uploads.image)}>
          {error_to_string(err)}
        </.error>

        <.live_file_input
          upload={@uploads.image}
          class="absolute w-px h-px p-0 -m-px overflow-hidden border-0 opacity-0 pointer-events-none"
        />

        <%= if @has_image do %>
          <div class="relative w-full flex flex-col items-center gap-4 flex-1">
            <label
              for={@uploads.image.ref}
              class="absolute inset-0 z-0 cursor-pointer"
              data-upload-trigger="true"
              aria-label="Select more images"
            >
            </label>

            <div class="relative z-10 w-full flex flex-col items-center gap-4 flex-1 pointer-events-none">
              <%= for entry <- @uploads.image.entries do %>
                <article class="upload-entry relative w-full max-w-xs aspect-square pointer-events-auto">
                  <figure class="w-full h-full">
                    <.live_img_preview entry={entry} class="w-full h-full object-cover rounded-lg" />
                  </figure>

                  <%= if entry.progress == 0 do %>
                    <.button
                      type="button"
                      size="sm"
                      phx-target={@myself}
                      phx-click="cancel-image"
                      phx-value-ref={entry.ref}
                      aria-label="cancel"
                      class="absolute top-2 right-2 btn-circle z-10"
                    >
                      &times;
                    </.button>
                  <% end %>

                  <div
                    :for={err <- upload_errors(@uploads.image, entry)}
                    class="mt-2 text-xs text-error"
                  >
                    {error_to_string(err)}
                  </div>

                  <%= case entry.progress do %>
                    <% 0 -> %>
                    <% 100 -> %>
                      <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm bg-black bg-opacity-30 rounded-lg">
                        <div
                          class="radial-progress text-white"
                          style="--value:100; --size:2rem; --thickness: 2px;"
                          role="progressbar"
                        >
                          <.icon name="hero-check" class="size-6" />
                        </div>
                      </div>
                    <% _ -> %>
                      <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm bg-black bg-opacity-30 rounded-lg">
                        <div
                          class="radial-progress text-white"
                          style={"--value:#{entry.progress}; --size:2rem; --thickness: 2px;"}
                          role="progressbar"
                        >
                          <.icon name="hero-check" class="size-6" />
                        </div>
                      </div>
                  <% end %>
                </article>
              <% end %>

              <div class="flex gap-2 mt-auto pointer-events-auto">
                <.button
                  type="submit"
                  name="intent"
                  value="search"
                  variant="submit"
                  disabled={@uploading or not @can_search_image}
                >
                  <%= if @uploading do %>
                    Uploading...
                  <% else %>
                    Search
                  <% end %>
                </.button>
                <.button
                  type="submit"
                  name="intent"
                  value="upload-only"
                  variant="outline"
                  disabled={@uploading}
                >
                  <%= if @uploading do %>
                    Uploading...
                  <% else %>
                    Upload
                  <% end %>
                </.button>
              </div>
              <p :if={!@single_image} class="text-xs text-base-content/60 mt-1 text-center">
                {gettext(
                  "Search by image supports exactly one image. Use Upload for multiple images."
                )}
              </p>
            </div>
          </div>
        <% else %>
          <div class="relative w-full flex-1 min-h-[14rem]">
            <label
              for={@uploads.image.ref}
              class="absolute inset-0 z-0 cursor-pointer"
              data-upload-trigger="true"
              aria-label="Select images"
            >
            </label>
            <div class="absolute inset-0 z-10 flex flex-col justify-center items-center pointer-events-none text-center">
              <img src="/images/undraw_images.svg" alt="Upload images" class="h-20 w-auto" />
              <div class="text-xs text-base-content/60 mt-4">
                {gettext("Drop images here or click to upload")}
              </div>
            </div>
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Image is too large (max 12MB)"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end

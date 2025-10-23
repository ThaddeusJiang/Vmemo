defmodule VmemoWeb.LiveComponents.UploadForm do
  use VmemoWeb, :live_component

  alias VmemoWeb.LiveComponents.Waterfall

  alias Vmemo.PhotoService
  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.Note
  alias Vmemo.Photos.PhotoNote
  alias SmallSdk.FileSystem

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:photos,
       accept: ~w(.png .jpg .jpeg .gif .webp),
       max_entries: 100
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(%{
         "note" => "",
         "is_whole" => false
       })
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form
      id="upload-form"
      phx-target={@myself}
      phx-submit="save"
      phx-change="validate"
      class=" w-full mx-auto max-w-md lg:max-w-lg"
      phx-hook="ClipboardMediaFetcher"
      phx-drop-target={@uploads.photos.ref}
    >
      <label for={@uploads.photos.ref} class="relative h-auto">
        <section class=" aspect-auto sm:aspect-video relative flex flex-col w-full rounded-lg border-2 border-dashed border-gray-300 bg-base-100 p-4 text-center hover:border-primary hover:bg-base-200 hover:shadow-lg hover:cursor-pointer focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 transition-all duration-200 ">
          <.live_component
            id="waterfall-upload-photos"
            module={Waterfall}
            items={@uploads.photos.entries}
          >
            <:empty>
              <div class="  w-full h-full flex flex-col justify-center items-center">
                <img src="/images/undraw_images.svg" alt="Upload photos" class="w-1/2 h-auto" />
              </div>
            </:empty>

            <:card :let={entry}>
              <article class="upload-entry relative">
                <figure>
                  <.live_img_preview entry={entry} />
                </figure>

                <%= case entry.progress do %>
                  <% 0 -> %>
                    <.button
                      type="button"
                      phx-target={@myself}
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      aria-label="cancel"
                      class="absolute top-1 right-1 btn btn-xs btn-circle btn-info"
                    >
                      &times;
                    </.button>
                  <% 100 -> %>
                    <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm ">
                      <div
                        class=" radial-progress text-white"
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
                    <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm ">
                      <div
                        class=" radial-progress text-white "
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
            </:card>
          </.live_component>

          <label
            for={@uploads.photos.ref}
            class="block flex-none py-2 rounded-3xl place-content-center hover:cursor-pointer"
          >
            <span class="text-sm text-gray-600 font-medium">
              Drag and drop images here or click to upload
            </span>
          </label>

          <.live_file_input upload={@uploads.photos} class="hidden" />
        </section>
      </label>

      <p :for={err <- upload_errors(@uploads.photos)} class="alert alert-danger">
        {error_to_string(err)}
      </p>

      <div :if={Enum.count(@uploads.photos.entries) > 0} class="mt-4 space-y-2">
        <.textarea_field
          id={@form[:note].id}
          name={@form[:note].name}
          value={@form[:note].value}
          label="Note"
        />

        <.input field={@form[:is_whole]} type="checkbox" label="Is whole" />
      </div>

      <footer :if={Enum.count(@uploads.photos.entries) > 0} class="flex justify-center mt-4">
        <.button>Upload</.button>
      </footer>
    </form>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  @impl true
  def handle_event(
        "save",
        %{"note" => note_text, "is_whole" => is_whole},
        socket
      ) do
    user_id = socket.assigns.current_user.id

    note =
      case is_whole do
        "true" ->
          case Note.create_with_sync(%{
                 text: note_text,
                 user_id: user_id |> Integer.to_string()
               }, actor: socket.assigns.current_user) do
            {:ok, note} -> note
            {:error, _} -> nil
          end

        _ ->
          nil
      end

    case uploaded_entries(socket, :photos) do
      {[_ | _] = entries, []} ->
        results =
          for entry <- entries do
            consume_uploaded_entry(socket, entry, fn %{path: path} ->
              filename = entry.uuid <> Path.extname(entry.client_name)

              {:ok, dest} = PhotoService.cp_file(path, user_id, filename)

              image_base64 = FileSystem.read_image_base64(dest)

              if image_base64 == nil do
                {:error, "Failed to read image file"}
              else
                case Photo.create_with_sync(%{
                       image: image_base64,
                       note: note_text,
                       url: Path.join("/", dest),
                       file_id: filename,
                       user_id: user_id |> Integer.to_string()
                     }, actor: socket.assigns.current_user) do
                  {:ok, photo} -> {:ok, photo}
                  {:error, reason} -> {:error, reason}
                end
              end
            end)
          end

        case Enum.find(results, fn result -> match?({:error, _}, result) end) do
          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to upload photo: #{reason}")}

          nil ->
            photos =
              results
              |> Enum.filter(fn result -> match?({:ok, _}, result) end)
              |> Enum.map(fn {:ok, photo} -> photo end)

            if note != nil do
              for photo <- photos do
                Ash.create(PhotoNote, %{
                  photo_id: photo.id,
                  note_id: note.id
                })
              end
            end

            {:noreply,
             socket
             |> put_flash(:info, "Photos uploaded successfully")
             |> push_navigate(to: "/photos")}
        end

      _ ->
        {:noreply, socket}
    end
  end
end

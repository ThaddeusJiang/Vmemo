defmodule VmemoWeb.LiveComponents.UploadForm do
  use VmemoWeb, :live_component

  import VmemoWeb.Live.FocusHelpers

  alias VmemoWeb.LiveComponents.Waterfall

  alias Vmemo.PhotoService
  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.Note
  alias Vmemo.Photos.PhotoNote

  @impl true
  def mount(socket) do
    socket =
      socket
      |> allow_upload(:photos,
        accept: ~w(.png .jpg .jpeg .gif .webp),
        max_entries: 100
      )

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn ->
        to_form(%{
          "note" => "",
          "is_whole" => true
        })
      end)
      |> assign_new(:show_full_form, fn -> false end)

    # 通知父组件文件状态变化和 upload ref
    # 使用 socket.parent_pid 获取父 LiveView 的 PID
    has_files = Enum.any?(socket.assigns.uploads.photos.entries)
    upload_ref = socket.assigns.uploads.photos.ref

    if socket.parent_pid do
      send(socket.parent_pid, {:upload_form_has_files, has_files})
      # 确保 ref 总是发送（可能在组件更新时 ref 变化）
      send(socket.parent_pid, {:upload_form_ref, upload_ref})
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    has_files = Enum.any?(assigns.uploads.photos.entries)

    assigns =
      assigns
      |> assign(:has_files, has_files)
      |> assign(
        :form_class,
        if(has_files or assigns.show_full_form,
          do: "w-full mx-auto max-w-md lg:max-w-lg",
          else: "absolute inset-0 pointer-events-none z-0"
        )
      )
      |> assign(
        :label_class,
        if(has_files or assigns.show_full_form,
          do: "relative h-auto",
          else: "relative h-full pointer-events-auto"
        )
      )
      |> assign(
        :section_class,
        if(has_files or assigns.show_full_form,
          do:
            "aspect-auto sm:aspect-video relative flex flex-col w-full rounded-lg border-2 border-dashed border-gray-300 bg-base-100 p-4 text-center hover:border-primary hover:bg-base-200 hover:shadow-lg hover:cursor-pointer focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 transition-all duration-200",
          else: "relative flex flex-col w-full h-full border-0 bg-transparent"
        )
      )

    ~H"""
    <form
      id="upload-form"
      phx-target={@myself}
      phx-submit="save"
      phx-change="validate"
      class={@form_class}
      phx-hook="ClipboardMediaFetcher"
      phx-drop-target={@uploads.photos.ref}
    >
      <label for={@uploads.photos.ref} class={@label_class}>
        <section class={@section_class}>
          <.live_component
            id="waterfall-upload-photos"
            module={Waterfall}
            items={@uploads.photos.entries}
          >
            <:empty>
              <div class="w-full h-full flex flex-col justify-center items-center">
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
                      class="absolute top-1 right-1 btn btn-circle btn-info"
                    >
                      &times;
                    </.button>
                  <% 100 -> %>
                    <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm">
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
                    <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm">
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

      <%= if @has_files or @show_full_form do %>
        <p :for={err <- upload_errors(@uploads.photos)} class="alert alert-danger">
          {error_to_string(err)}
        </p>

        <div :if={@has_files} class="mt-4 space-y-1">
          <.textarea_field
            id={@form[:note].id}
            name={@form[:note].name}
            value={@form[:note].value}
            label="Note"
            phx-hook="Focus"
          />

          <.input field={@form[:is_whole]} type="checkbox" label="Is whole" />
        </div>

        <footer :if={@has_files} class="flex justify-center mt-4">
          <.button>Upload</.button>
        </footer>
      <% else %>
        <p :for={err <- upload_errors(@uploads.photos)} class="hidden">
          {error_to_string(err)}
        </p>
      <% end %>
    </form>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  @impl true
  def handle_event("validate", params, socket) do
    current_file_count = length(socket.assigns.uploads.photos.entries)
    previous_file_count = Map.get(socket.assigns, :previous_file_count, 0)
    upload_ref = socket.assigns.uploads.photos.ref
    has_files = current_file_count > 0
    file_count_changed = current_file_count != previous_file_count

    # 通知父组件文件状态变化
    if socket.parent_pid do
      send(socket.parent_pid, {:upload_form_has_files, has_files})
      send(socket.parent_pid, {:upload_form_ref, upload_ref})
    end

    # 合并表单数据
    current_form_data = socket.assigns.form.params || %{}
    new_form_data = Map.merge(current_form_data, params)

    socket =
      socket
      |> assign(form: to_form(new_form_data))
      |> assign(previous_file_count: current_file_count)
      |> maybe_focus_note_field(file_count_changed and has_files)

    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    previous_file_count = length(socket.assigns.uploads.photos.entries)

    socket = cancel_upload(socket, :photos, ref)

    current_file_count = length(socket.assigns.uploads.photos.entries)
    has_files = current_file_count > 0
    file_count_changed = current_file_count != previous_file_count

    socket =
      socket
      |> assign(previous_file_count: current_file_count)
      |> maybe_focus_note_field(file_count_changed and has_files)

    {:noreply, socket}
  end

  def handle_event(
        "save",
        %{"note" => note_text, "is_whole" => is_whole},
        socket
      ) do
    current_user =
      Map.get(socket.assigns, :current_ash_user) || Map.get(socket.assigns, :current_user)

    if is_nil(current_user) do
      {:noreply, socket |> put_flash(:error, "User not found")}
    else
      ash_user_id = current_user.id

      note =
        case is_whole do
          "true" ->
            case Note.create_with_sync(
                   %{
                     text: note_text,
                     ash_user_id: ash_user_id
                   },
                   actor: current_user
                 ) do
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

                {:ok, dest} = PhotoService.cp_file(path, ash_user_id, filename)

                case Photo.create_with_sync(
                       %{
                         note: note_text,
                         url: Path.join("/", dest),
                         file_id: filename,
                         ash_user_id: ash_user_id
                       },
                       actor: current_user
                     ) do
                  {:ok, photo} -> {:ok, {:ok, photo}}
                  {:error, reason} -> {:ok, {:error, reason}}
                end
              end)
            end

          # Handle results: can be {:ok, {:ok, photo}}, {:ok, {:error, reason}}, or {:error, reason}
          results =
            results
            |> Enum.map(fn
              {:ok, r} -> r
              {:error, reason} -> {:error, reason}
              other -> {:error, inspect(other)}
            end)

          case Enum.find(results, fn result -> match?({:error, _}, result) end) do
            {:error, %Ash.Error.Unknown{} = ash_error} ->
              error_msg =
                ash_error.errors
                |> List.first()
                |> case do
                  %Ash.Error.Unknown.UnknownError{error: msg} when is_binary(msg) ->
                    # Extract the actual error message from the nested error
                    msg

                  %{error: msg} when is_binary(msg) ->
                    msg

                  _ ->
                    "Database error occurred"
                end

              {:noreply, socket |> put_flash(:error, error_msg)}

            {:error, reason} when is_binary(reason) ->
              {:noreply, socket |> put_flash(:error, reason)}

            {:error, _reason} ->
              {:noreply, socket |> put_flash(:error, "Upload error occurred")}

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

              # 通知父组件上传成功，传递图片列表
              if socket.parent_pid do
                send(socket.parent_pid, {:upload_success, photos})
              end

              {:noreply,
               socket
               |> put_flash(:info, "Photos uploaded successfully")}
          end

        _ ->
          {:noreply, socket}
      end
    end
  end

  defp maybe_focus_note_field(socket, true) do
    focus(socket, "#note")
  end

  defp maybe_focus_note_field(socket, false), do: socket
end

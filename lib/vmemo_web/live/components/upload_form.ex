defmodule VmemoWeb.LiveComponents.UploadForm do
  @moduledoc false
  use VmemoWeb, :live_component

  import VmemoWeb.Live.FocusHelpers

  alias VmemoWeb.LiveComponents.PhotoCard
  alias VmemoWeb.LiveComponents.Waterfall

  alias Vmemo.Memo.Note
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.Photo
  alias Vmemo.Memo.PhotoNote
  alias Vmemo.Memo.ImageStorage

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
      |> assign_new(:uploaded_photos, fn -> [] end)

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
          do: "w-full mx-auto max-w-screen-xl h-full min-h-0 flex flex-col overflow-hidden",
          else:
            "absolute inset-0 pointer-events-none z-0 h-full min-h-0 flex flex-col overflow-hidden"
        )
      )
      |> assign(
        :label_class,
        if(has_files or assigns.show_full_form,
          do: "relative flex-1 min-h-0 block",
          else: "relative h-full min-h-0 pointer-events-auto block"
        )
      )
      |> assign(
        :section_class,
        if(has_files or assigns.show_full_form,
          do:
            "relative flex flex-col w-full h-[32rem] max-h-[32rem] min-h-0 rounded-lg border-2 border-dashed border-gray-300 bg-base-100 p-4 text-center hover:border-primary hover:bg-base-200 hover:shadow-lg hover:cursor-pointer focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 transition-all duration-200 overflow-hidden",
          else:
            "relative flex flex-col w-full h-full min-h-0 border-0 bg-transparent overflow-hidden"
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
      <div class="flex-1 min-h-0 flex flex-col gap-4 overflow-hidden">
        <section class="flex-1 min-h-0 flex flex-col overflow-hidden">
          <label for={@uploads.photos.ref} class={@label_class}>
            <section class={@section_class}>
              <.live_component
                id="waterfall-upload-photos"
                module={Waterfall}
                items={@uploads.photos.entries}
                class="flex-1 min-h-0 overflow-y-auto pr-1"
              >
                <:empty>
                  <div class="w-full h-full flex flex-col justify-center items-center">
                    <img src="/images/undraw_images.svg" alt="Upload photos" class="w-1/2 h-auto" />
                  </div>
                </:empty>

                <:card :let={entry}>
                  <PhotoCard.photo_card>
                    <:media>
                      <.live_img_preview
                        entry={entry}
                        class="w-full h-auto object-cover rounded-lg shadow hover:shadow-lg hover:transition-transform"
                      />
                    </:media>
                    <:overlay>
                      <%= case entry.progress do %>
                        <% 0 -> %>
                          <.button
                            type="button"
                            phx-target={@myself}
                            phx-click="cancel-upload"
                            phx-value-ref={entry.ref}
                            aria-label="cancel"
                            class="absolute top-2 right-2 btn btn-circle btn-sm btn-neutral"
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
                    </:overlay>
                  </PhotoCard.photo_card>
                  <div
                    :for={err <- upload_errors(@uploads.photos, entry)}
                    class="mt-2 text-xs text-error"
                  >
                    {error_to_string(err)}
                  </div>
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
            <div :for={err <- upload_errors(@uploads.photos)} class="alert alert-danger mt-3">
              {error_to_string(err)}
            </div>

            <div :if={@has_files} class="mt-4 space-y-1 flex-none">
              <.textarea_field
                id={@form[:note].id}
                name={@form[:note].name}
                value={@form[:note].value}
                label="Note"
                phx-hook="Focus"
              />

              <.input field={@form[:is_whole]} type="checkbox" label="Is whole" />
            </div>

            <footer :if={@has_files} class="flex justify-center mt-4 flex-none">
              <.button>Upload</.button>
            </footer>
          <% else %>
            <div :for={err <- upload_errors(@uploads.photos)} class="hidden">
              {error_to_string(err)}
            </div>
          <% end %>
        </section>

        <section :if={Enum.any?(@uploaded_photos)} class="h-1/3 min-h-0 flex flex-col overflow-hidden">
          <div class="mb-2 text-left text-sm font-medium text-base-content/70 flex-none">
            Uploaded
          </div>
          <.live_component
            id="waterfall-uploaded-photos"
            module={Waterfall}
            items={@uploaded_photos}
            class="flex-1 min-h-0 overflow-y-auto pr-1"
          >
            <:card :let={photo}>
              <PhotoCard.photo_card photo={photo}>
                <:overlay>
                  <.uploaded_photo_status_overlay photo={photo} />
                </:overlay>
              </PhotoCard.photo_card>
            </:card>
          </.live_component>
        </section>
      </div>
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
    current_user = Map.get(socket.assigns, :current_user)

    if is_nil(current_user) do
      {:noreply, socket |> put_flash(:error, "User not found")}
    else
      user_id = current_user.id

      note =
        case is_whole do
          "true" ->
            case Note.create_with_sync(
                   %{
                     text: note_text,
                     user_id: user_id
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

                {:ok, dest} = ImageStorage.cp_file(path, user_id, filename)

                case Image.create_with_sync(
                       %{
                         note: note_text,
                         url: Path.join("/", dest),
                         file_id: filename,
                         user_id: user_id,
                         inner_purpose: nil
                       },
                       actor: current_user
                     ) do
                  {:ok, photo} -> {:ok, {:ok, photo}}
                  {:error, reason} -> {:ok, {:error, reason}}
                end
              end)
            end

          results = Enum.map(results, &normalize_upload_result/1)

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
                |> Enum.filter(&match?({:ok, _}, &1))
                |> Enum.map(fn {:ok, photo} -> photo end)

              case maybe_link_note_to_photos(note, photos, current_user) do
                :ok ->
                  send(self(), {:upload_success, photos})

                  {:noreply,
                   update(socket, :uploaded_photos, &append_uploaded_photos(&1, photos))}

                {:error, _reason} ->
                  {:noreply,
                   socket |> put_flash(:error, "Failed to link note to uploaded photos")}
              end
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

  defp normalize_upload_result({:ok, %Photo{} = photo}), do: {:ok, photo}
  defp normalize_upload_result({:error, _reason} = error), do: error
  defp normalize_upload_result(%Photo{} = photo), do: {:ok, photo}
  defp normalize_upload_result(other), do: {:error, inspect(other)}

  attr :photo, :map, required: true

  defp uploaded_photo_status_overlay(assigns) do
    ~H"""
    <div class="absolute top-2 right-2 dropdown dropdown-hover dropdown-end">
      <button
        type="button"
        tabindex="0"
        class={
          "inline-flex items-center justify-center rounded-full p-1.5 bg-base-100/90 shadow-lg " <>
            uploaded_photo_status_icon_class(@photo)
        }
        title={uploaded_photo_status_label(@photo)}
        aria-label={uploaded_photo_status_label(@photo)}
      >
        <.uploaded_photo_status_icon status={uploaded_photo_status(@photo)} />
      </button>
      <div
        tabindex="0"
        class="dropdown-content z-10 mt-1 w-56 rounded-md border border-base-300 bg-base-100 p-2 text-xs shadow-lg"
      >
        <div class="font-medium text-base-content mb-1">Processing details</div>
        <div class="flex items-center justify-between gap-2 text-base-content/80">
          <div>Search Engine</div>
          <div class={uploaded_service_status_class(@photo.typesense_status)}>
            {uploaded_service_status_text(@photo.typesense_status)}
          </div>
        </div>
        <div class="flex items-center justify-between gap-2 text-base-content/80 mt-1">
          <div>Vision AI</div>
          <div class={uploaded_service_status_class(@photo.moondream_status)}>
            {uploaded_service_status_text(@photo.moondream_status)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp uploaded_photo_status_icon(assigns) do
    ~H"""
    <%= case @status do %>
      <% :success -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-4">
          <path
            fill-rule="evenodd"
            d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12Zm13.36-1.814a.75.75 0 1 0-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 0 0-1.06 1.06l2.25 2.25a.75.75 0 0 0 1.14-.094l3.75-5.25Z"
            clip-rule="evenodd"
          />
        </svg>
      <% :error -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-4">
          <path
            fill-rule="evenodd"
            d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12Zm9-4.5a.75.75 0 0 0-1.5 0v5.25a.75.75 0 0 0 1.5 0V7.5Zm0 9a.75.75 0 0 0-1.5 0v.75a.75.75 0 0 0 1.5 0v-.75Z"
            clip-rule="evenodd"
          />
        </svg>
      <% :processing -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="currentColor"
          class="size-4 animate-pulse"
        >
          <path d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.283-3.283L2.06 11.81l2.845-.813a4.5 4.5 0 0 0 3.283-3.283L9 4.86l.813 2.845a4.5 4.5 0 0 0 3.283 3.283l2.845.813-2.845.813a4.5 4.5 0 0 0-3.283 3.283ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.455L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.455L18 2.25l.259 1.036a3.375 3.375 0 0 0 2.455 2.455L21.75 6l-1.036.259a3.375 3.375 0 0 0-2.455 2.455ZM16.894 20.567 17.25 21.75l.356-1.183a2.25 2.25 0 0 1 1.567-1.567l1.183-.356-1.183-.356a2.25 2.25 0 0 1-1.567-1.567l-.356-1.183-.356 1.183a2.25 2.25 0 0 1-1.567 1.567l-1.183.356 1.183.356a2.25 2.25 0 0 1 1.567 1.567Z" />
        </svg>
    <% end %>
    """
  end

  defp uploaded_photo_status(%Photo{} = photo) do
    statuses = [photo.typesense_status, photo.moondream_status]

    cond do
      Enum.any?(statuses, &(&1 == "failed")) -> :error
      Enum.all?(statuses, &(&1 == "completed")) -> :success
      true -> :processing
    end
  end

  defp uploaded_photo_status_icon_class(photo) do
    case uploaded_photo_status(photo) do
      :success -> "text-success"
      :error -> "text-error"
      :processing -> "text-info"
    end
  end

  defp uploaded_photo_status_label(photo) do
    case uploaded_photo_status(photo) do
      :success -> "Search engine and Vision AI processed successfully"
      :error -> "Search engine or Vision AI processing failed"
      :processing -> "Search engine or Vision AI is processing"
    end
  end

  defp uploaded_service_status_class(status) do
    case status do
      "completed" -> "text-success font-medium"
      "failed" -> "text-error font-medium"
      _ -> "text-info font-medium"
    end
  end

  defp uploaded_service_status_text(status) do
    case status do
      "completed" -> "Success"
      "failed" -> "Failed"
      "processing" -> "Processing"
      "pending" -> "Pending"
      _ -> "Processing"
    end
  end

  defp append_uploaded_photos(existing_photos, new_photos) do
    (existing_photos ++ new_photos)
    |> Enum.uniq_by(& &1.id)
  end

  defp maybe_link_note_to_photos(nil, _photos, _current_user), do: :ok

  defp maybe_link_note_to_photos(_note, [], _current_user), do: :ok

  defp maybe_link_note_to_photos(note, photos, current_user) do
    photos
    |> Enum.reduce_while(:ok, fn photo, _acc ->
      case Ash.create(
             PhotoNote,
             %{
               photo_id: photo.id,
               note_id: note.id
             },
             action: :import,
             actor: current_user
           ) do
        {:ok, _photo_note} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end
end

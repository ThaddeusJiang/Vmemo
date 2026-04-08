defmodule VmemoWeb.LiveComponents.UploadForm do
  @moduledoc false
  use VmemoWeb, :live_component

  import VmemoWeb.Live.FocusHelpers

  alias VmemoWeb.LiveComponents.Waterfall

  alias Vmemo.Memo.Note
  alias Vmemo.Memo.Photo
  alias Vmemo.Memo.PhotoNote
  alias Vmemo.Memo.PhotoStorage
  alias Vmemo.Memo.UploadSession
  alias Vmemo.Memo.UploadSessionItem
  require Ash.Query

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
      |> assign_new(:upload_items, fn -> [] end)
      |> assign_new(:queue_message, fn -> nil end)
      |> assign_new(:current_note, fn -> nil end)
      |> assign_new(:current_upload_session, fn -> nil end)

    socket =
      case {socket.assigns.current_upload_session, Map.get(socket.assigns, :current_user)} do
        {%UploadSession{} = session, current_user} when not is_nil(current_user) ->
          assign(socket, :upload_items, load_upload_items(session, current_user))

        _ ->
          socket
      end

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

                <p
                  :for={err <- upload_errors(@uploads.photos, entry)}
                  class="mt-2 text-xs text-error text-left"
                >
                  {error_to_string(err)}
                </p>
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

          <.live_file_input upload={@uploads.photos} class="hidden" phx-hook="UploadResumeQueue" />
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

      <div :if={@queue_message} class="alert alert-info mt-4 text-sm">
        {@queue_message}
      </div>

      <div :if={Enum.any?(@upload_items)} class="mt-6 space-y-2">
        <div class="font-medium">Upload Items</div>
        <div class="max-h-72 overflow-y-auto overflow-x-hidden space-y-2">
          <div :for={item <- @upload_items} class="rounded border border-base-300 p-2">
            <div class="text-sm truncate">{item.file_name}</div>
            <div class="text-xs opacity-70">Upload: {item.status}</div>
            <div class="text-xs opacity-70">Typesense: {typesense_status(item.status)}</div>
            <div class="text-xs opacity-70">Moondream: {moondream_status(item.status)}</div>
          </div>
        </div>
      </div>
    </form>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  @impl true
  def handle_event("validate", params, socket) do
    try do
      current_file_count = length(socket.assigns.uploads.photos.entries)
      previous_file_count = Map.get(socket.assigns, :previous_file_count, 0)
      upload_ref = socket.assigns.uploads.photos.ref
      has_files = current_file_count > 0
      file_count_changed = current_file_count != previous_file_count

      if socket.parent_pid do
        send(socket.parent_pid, {:upload_form_has_files, has_files})
        send(socket.parent_pid, {:upload_form_ref, upload_ref})
      end

      current_form_data = socket.assigns.form.params || %{}

      new_form_data =
        if is_map(params), do: Map.merge(current_form_data, params), else: current_form_data

      note_text = Map.get(new_form_data, "note", "")

      current_note =
        socket.assigns.current_note
        |> maybe_update_existing_note(note_text, socket.assigns.current_user)

      socket =
        socket
        |> assign(form: to_form(new_form_data))
        |> assign(previous_file_count: current_file_count)
        |> assign(current_note: current_note)
        |> maybe_focus_note_field(file_count_changed and has_files)

      {:noreply, socket}
    rescue
      error ->
        {:noreply, socket |> put_flash(:error, "Validate failed: #{Exception.message(error)}")}
    end
  end

  def handle_event("queue-persisted", params, socket) do
    try do
      {:noreply, persist_upload_session_from_queue(socket, params, "Saved")}
    rescue
      error ->
        {:noreply, socket |> put_flash(:error, "Queue save failed: #{Exception.message(error)}")}
    end
  end

  def handle_event("queue-restored", params, socket) do
    try do
      {:noreply, persist_upload_session_from_queue(socket, params, "Restored")}
    rescue
      error ->
        {:noreply,
         socket |> put_flash(:error, "Queue restore failed: #{Exception.message(error)}")}
    end
  end

  def handle_event("queue-persist-failed", _params, socket) do
    {:noreply, put_flash(socket, :error, "Failed to save files to local queue")}
  end

  def handle_event("queue-restore-failed", _params, socket) do
    {:noreply, put_flash(socket, :error, "Failed to restore files from local queue")}
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
    try do
      current_user = Map.get(socket.assigns, :current_user)

      if is_nil(current_user) do
        {:noreply, socket |> put_flash(:error, "User not found")}
      else
        user_id = current_user.id

        note =
          ensure_note_for_upload(socket.assigns.current_note, is_whole, note_text, current_user)

        upload_session =
          ensure_upload_session(
            socket.assigns.current_upload_session,
            current_user,
            %{count: length(socket.assigns.uploads.photos.entries)}
          )

        upload_session =
          attach_note_to_upload_session(upload_session, note, current_user)

        case uploaded_entries(socket, :photos) do
          {[_ | _] = entries, []} ->
            results =
              for entry <- entries do
                item =
                  ensure_upload_item(upload_session, entry, current_user)
                  |> mark_item_status("uploading", current_user)

                consume_uploaded_entry(socket, entry, fn %{path: path} ->
                  filename = entry.uuid <> Path.extname(entry.client_name)

                  {:ok, dest} = PhotoStorage.cp_file(path, user_id, filename)

                  result =
                    get_or_create_photo(
                      filename,
                      %{
                        note: note_text,
                        url: Path.join("/", dest),
                        file_id: filename,
                        user_id: user_id
                      },
                      current_user
                    )

                  item = mark_item_result(item, result, current_user)
                  _ = item
                  {:ok, result}
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

                    upload_session =
                      mark_upload_session_counts(upload_session, results, current_user)
                      |> maybe_mark_upload_session_completed(current_user)

                    socket =
                      socket
                      |> assign(:current_note, note)
                      |> assign(:upload_items, load_upload_items(upload_session, current_user))
                      |> assign(:current_upload_session, upload_session)
                      |> assign(:queue_message, "Upload finished")
                      |> push_event("upload_queue_clear", %{})

                    {:noreply, socket}

                  {:error, _reason} ->
                    {:noreply,
                     socket |> put_flash(:error, "Failed to link note to uploaded photos")}
                end
            end

          _ ->
            {:noreply, socket}
        end
      end
    rescue
      error ->
        {:noreply, socket |> put_flash(:error, "Upload failed: #{Exception.message(error)}")}
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
          if duplicate_photo_note_error?(reason) do
            {:cont, :ok}
          else
            {:halt, {:error, reason}}
          end
      end
    end)
  end

  defp ensure_note_for_upload(existing_note, "true", note_text, current_user) do
    case existing_note do
      %Note{} = note ->
        maybe_update_existing_note(note, note_text, current_user)

      _ ->
        case Note.create_with_sync(
               %{
                 text: note_text,
                 user_id: current_user.id
               },
               actor: current_user
             ) do
          {:ok, note} -> note
          {:error, _reason} -> nil
        end
    end
  end

  defp ensure_note_for_upload(_existing_note, _is_whole, _note_text, _current_user), do: nil

  defp maybe_update_existing_note(%Note{} = note, note_text, current_user) do
    normalized = String.trim(note_text || "")
    previous = String.trim(note.text || "")

    if normalized == previous do
      note
    else
      case Note.update(note, %{text: note_text}, actor: current_user) do
        {:ok, updated} -> updated
        {:error, _reason} -> note
      end
    end
  end

  defp maybe_update_existing_note(_note, _note_text, _current_user), do: nil

  defp get_or_create_photo(file_id, attrs, current_user) do
    query =
      Photo
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(file_id == ^file_id and user_id == ^current_user.id)
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: current_user) do
      {:ok, [%Photo{} = photo | _]} ->
        {:ok, photo}

      _ ->
        case Photo.create_with_sync(attrs, actor: current_user) do
          {:ok, photo} -> {:ok, photo}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp duplicate_photo_note_error?(reason) do
    inspect(reason) |> String.contains?("has already been taken")
  end

  defp load_upload_items(nil, _current_user), do: []

  defp load_upload_items(session, current_user) do
    query =
      UploadSessionItem
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(upload_session_id == ^session.id)
      |> Ash.Query.sort(order_index: :asc)

    case Ash.read(query, actor: current_user) do
      {:ok, items} -> items
      _ -> []
    end
  end

  defp typesense_status(status) when status in ["uploaded", "linked"], do: "processing"
  defp typesense_status("failed"), do: "failed"
  defp typesense_status("completed"), do: "completed"
  defp typesense_status(_status), do: "queued"

  defp moondream_status(status) when status in ["uploaded", "linked"], do: "processing"
  defp moondream_status("failed"), do: "failed"
  defp moondream_status("completed"), do: "completed"
  defp moondream_status(_status), do: "queued"

  defp persist_upload_session_from_queue(socket, params, action_label) do
    count = parse_count(params["count"])
    current_user = Map.get(socket.assigns, :current_user)

    socket =
      if is_nil(current_user) do
        socket
      else
        session =
          ensure_upload_session(socket.assigns.current_upload_session, current_user, %{
            client_session_key: params["client_session_key"],
            count: count
          })

        sync_upload_session_items(session, params["files"] || [], current_user)

        socket
        |> assign(:current_upload_session, session)
        |> assign(:upload_items, load_upload_items(session, current_user))
      end

    assign(socket, :queue_message, "#{action_label} #{count} files to local queue")
  end

  defp ensure_upload_session(%UploadSession{} = session, _current_user, %{client_session_key: nil}),
       do: session

  defp ensure_upload_session(_session, current_user, params) do
    client_session_key =
      params[:client_session_key] || "fallback_#{System.system_time(:millisecond)}"

    total_count = params[:count] || 0

    query =
      UploadSession
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(
        user_id == ^current_user.id and client_session_key == ^client_session_key
      )
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: current_user) do
      {:ok, [%UploadSession{} = session | _]} ->
        case UploadSession.update(session, %{total_count: total_count}, actor: current_user) do
          {:ok, updated} -> updated
          {:error, _reason} -> session
        end

      _ ->
        case UploadSession.create(
               %{
                 user_id: current_user.id,
                 client_session_key: client_session_key,
                 status: "pending",
                 total_count: total_count
               },
               actor: current_user
             ) do
          {:ok, session} -> session
          {:error, _reason} -> nil
        end
    end
  end

  defp sync_upload_session_items(nil, _files, _current_user), do: :ok

  defp sync_upload_session_items(session, files, current_user) when is_list(files) do
    Enum.each(files, fn file ->
      ensure_upload_item_by_payload(session, file, current_user)
    end)
  end

  defp ensure_upload_item_by_payload(session, file, current_user) do
    fingerprint = to_string(file["fingerprint"] || "")

    query =
      UploadSessionItem
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(
        upload_session_id == ^session.id and client_file_fingerprint == ^fingerprint
      )
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: current_user) do
      {:ok, [%UploadSessionItem{} = item | _]} ->
        item

      _ ->
        UploadSessionItem.create(
          %{
            upload_session_id: session.id,
            order_index: parse_count(file["order"]),
            client_file_fingerprint: fingerprint,
            file_name: to_string(file["name"] || "unknown"),
            mime_type: to_string(file["type"] || ""),
            size: parse_count(file["size"]),
            status: "queued"
          },
          actor: current_user
        )
        |> case do
          {:ok, item} -> item
          _ -> nil
        end
    end
  end

  defp ensure_upload_item(nil, _entry, _current_user), do: nil

  defp ensure_upload_item(session, entry, current_user) do
    fingerprint = entry_fingerprint(entry)

    ensure_upload_item_by_payload(
      session,
      %{
        "fingerprint" => fingerprint,
        "order" => 0,
        "name" => entry.client_name,
        "type" => entry.client_type,
        "size" => entry.client_size
      },
      current_user
    )
  end

  defp entry_fingerprint(entry) do
    last_modified = Map.get(entry, :client_last_modified, 0)
    "#{entry.client_name}:#{entry.client_size}:#{entry.client_type}:#{last_modified}"
  end

  defp mark_item_status(nil, _status, _current_user), do: nil

  defp mark_item_status(item, status, current_user) do
    case UploadSessionItem.update(item, %{status: status}, actor: current_user) do
      {:ok, updated} -> updated
      _ -> item
    end
  end

  defp mark_item_result(nil, _result, _current_user), do: nil

  defp mark_item_result(item, {:ok, photo}, current_user) do
    case UploadSessionItem.update(
           item,
           %{status: "uploaded", photo_id: photo.id, last_error: nil},
           actor: current_user
         ) do
      {:ok, updated} -> updated
      _ -> item
    end
  end

  defp mark_item_result(item, {:error, reason}, current_user) do
    case UploadSessionItem.update(
           item,
           %{
             status: "failed",
             retry_count: item.retry_count + 1,
             last_error: inspect(reason)
           },
           actor: current_user
         ) do
      {:ok, updated} -> updated
      _ -> item
    end
  end

  defp attach_note_to_upload_session(nil, _note, _current_user), do: nil
  defp attach_note_to_upload_session(session, nil, _current_user), do: session

  defp attach_note_to_upload_session(session, note, current_user) do
    case UploadSession.update(session, %{note_id: note.id}, actor: current_user) do
      {:ok, updated} -> updated
      _ -> session
    end
  end

  defp mark_upload_session_counts(nil, _results, _current_user), do: nil

  defp mark_upload_session_counts(session, results, current_user) do
    completed = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    attrs = %{
      completed_count: session.completed_count + completed,
      failed_count: session.failed_count + failed,
      status: if(failed > 0, do: "uploading", else: "pending")
    }

    case UploadSession.update(session, attrs, actor: current_user) do
      {:ok, updated} -> updated
      _ -> session
    end
  end

  defp maybe_mark_upload_session_completed(nil, _current_user), do: nil

  defp maybe_mark_upload_session_completed(session, current_user) do
    if session.total_count > 0 and session.completed_count >= session.total_count do
      case UploadSession.update(session, %{status: "completed"}, actor: current_user) do
        {:ok, updated} -> updated
        _ -> session
      end
    else
      session
    end
  end

  defp parse_count(value) when is_integer(value), do: value

  defp parse_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_count(_), do: 0
end

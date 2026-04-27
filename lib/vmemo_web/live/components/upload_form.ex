defmodule VmemoWeb.LiveComponents.UploadForm do
  @moduledoc false
  use VmemoWeb, :live_component

  require Logger

  import VmemoWeb.Live.FocusHelpers

  alias VmemoWeb.LiveComponents.ImageCard
  alias VmemoWeb.LiveComponents.Waterfall

  alias Vmemo.Memo.Note
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageNote
  alias Vmemo.Memo.ImageStorage

  @impl true
  def mount(socket) do
    socket =
      socket
      |> allow_upload(:images,
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

    has_files = Enum.any?(socket.assigns.uploads.images.entries)
    upload_ref = socket.assigns.uploads.images.ref

    if socket.parent_pid do
      send(socket.parent_pid, {:upload_form_has_files, has_files})
      send(socket.parent_pid, {:upload_form_ref, upload_ref})
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    has_files = Enum.any?(assigns.uploads.images.entries)

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
      phx-drop-target={@uploads.images.ref}
    >
      <div class="flex-1 min-h-0 flex flex-col gap-4 overflow-hidden">
        <section class="flex-1 min-h-0 flex flex-col overflow-hidden">
          <label for={@uploads.images.ref} class={@label_class}>
            <section class={@section_class}>
              <.live_component
                id="waterfall-upload-images"
                module={Waterfall}
                items={@uploads.images.entries}
                class="flex-1 min-h-0 overflow-y-auto pr-1"
              >
                <:empty>
                  <div class="w-full h-full flex flex-col justify-center items-center">
                    <img src="/images/undraw_images.svg" alt="Upload images" class="w-1/2 h-auto" />
                  </div>
                </:empty>

                <:card :let={entry}>
                  <ImageCard.image_card>
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
                              <.icon name="hero-check" class="size-6" />
                            </div>
                          </div>
                        <% _ -> %>
                          <div class="absolute inset-0 flex justify-center items-center backdrop-blur-sm">
                            <div
                              class="radial-progress text-white"
                              style={"--value:#{entry.progress}; --size:2rem; --thickness: 2px;"}
                              role="progressbar"
                            >
                              <.icon name="hero-check" class="size-6" />
                            </div>
                          </div>
                      <% end %>
                    </:overlay>
                  </ImageCard.image_card>
                  <div
                    :for={err <- upload_errors(@uploads.images, entry)}
                    class="mt-2 text-xs text-error"
                  >
                    {error_to_string(err)}
                  </div>
                </:card>
              </.live_component>

              <label
                for={@uploads.images.ref}
                class="block flex-none py-2 rounded-3xl place-content-center hover:cursor-pointer"
              >
                <span class="text-sm text-gray-600 font-medium">
                  Drag and drop images here or click to upload
                </span>
              </label>

              <.live_file_input upload={@uploads.images} class="hidden" />
            </section>
          </label>

          <%= if @has_files or @show_full_form do %>
            <.alert :for={err <- upload_errors(@uploads.images)} variant={:error} class="mt-3">
              {error_to_string(err)}
            </.alert>

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
            <div :for={err <- upload_errors(@uploads.images)} class="hidden">
              {error_to_string(err)}
            </div>
          <% end %>
        </section>

        <section :if={Enum.any?(@uploaded_photos)} class="h-1/3 min-h-0 flex flex-col overflow-hidden">
          <div class="mb-2 text-left text-sm font-medium text-base-content/70 flex-none">
            Uploaded
          </div>
          <.live_component
            id="waterfall-uploaded-images"
            module={Waterfall}
            items={@uploaded_photos}
            class="flex-1 min-h-0 overflow-y-auto pr-1"
          >
            <:card :let={image}>
              <ImageCard.image_card image={image}>
                <:overlay>
                  <.uploaded_photo_status_overlay image={image} />
                </:overlay>
              </ImageCard.image_card>
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
    current_file_count = length(socket.assigns.uploads.images.entries)
    previous_file_count = Map.get(socket.assigns, :previous_file_count, 0)
    upload_ref = socket.assigns.uploads.images.ref
    has_files = current_file_count > 0
    file_count_changed = current_file_count != previous_file_count

    if socket.parent_pid do
      send(socket.parent_pid, {:upload_form_has_files, has_files})
      send(socket.parent_pid, {:upload_form_ref, upload_ref})
    end

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
    previous_file_count = length(socket.assigns.uploads.images.entries)

    socket = cancel_upload(socket, :images, ref)

    current_file_count = length(socket.assigns.uploads.images.entries)
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
    case Map.get(socket.assigns, :current_user) do
      nil ->
        {:noreply, socket |> put_flash(:error, "User not found")}

      current_user ->
        handle_save_upload(socket, note_text, is_whole, current_user)
    end
  end

  defp maybe_focus_note_field(socket, true) do
    focus(socket, "#note")
  end

  defp maybe_focus_note_field(socket, false), do: socket

  defp handle_save_upload(socket, note_text, is_whole, current_user) do
    note = maybe_create_note(is_whole, note_text, current_user)

    case uploaded_entries(socket, :images) do
      {[_ | _] = entries, []} ->
        {:noreply, process_uploaded_images(socket, entries, note_text, note, current_user)}

      _ ->
        {:noreply, socket}
    end
  end

  defp maybe_create_note("true", note_text, current_user) do
    case Note.create_with_sync(%{text: note_text, user_id: current_user.id}, actor: current_user) do
      {:ok, note} -> note
      {:error, _} -> nil
    end
  end

  defp maybe_create_note(_is_whole, _note_text, _current_user), do: nil

  defp process_uploaded_images(socket, entries, note_text, note, current_user) do
    upload_batch_id = Ecto.UUID.generate()
    results = process_upload_entries(socket, entries, note_text, current_user, upload_batch_id)
    images = extract_successful_images(results)

    %{linked: linked_count, failed: link_failed_count} =
      maybe_link_note_to_photos(note, images, current_user)

    maybe_notify_upload_success(images)
    maybe_log_link_failure(link_failed_count)

    Logger.info(
      "Batch upload completed: total=#{length(entries)} success=#{length(images)} linked=#{linked_count} failed=#{length(results) - length(images)}"
    )

    socket
    |> update(:uploaded_photos, &append_uploaded_photos(&1, images))
    |> put_upload_result_flash(results, link_failed_count)
  end

  defp extract_successful_images(results) do
    results
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, image} -> image end)
  end

  defp maybe_notify_upload_success([]), do: :ok
  defp maybe_notify_upload_success(images), do: send(self(), {:upload_success, images})

  defp maybe_log_link_failure(link_failed_count) when link_failed_count > 0 do
    Logger.warning("Failed to link note to #{link_failed_count} uploaded image(s)")
  end

  defp maybe_log_link_failure(_), do: :ok

  defp process_upload_entries(socket, entries, note_text, current_user, upload_batch_id) do
    entries
    |> Enum.reduce([], fn entry, result_acc ->
      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          create_image_for_entry(path, entry, note_text, current_user, upload_batch_id)
        end)
        |> normalize_upload_result()

      [result | result_acc]
    end)
    |> Enum.reverse()
  end

  defp create_image_for_entry(path, entry, note_text, current_user, upload_batch_id) do
    user_id = current_user.id
    filename = entry.uuid <> Path.extname(entry.client_name)

    with {:ok, dest} <- ImageStorage.cp_file(path, user_id, filename),
         {:ok, image} <-
           Image.create_with_sync(
             %{
               note: note_text,
               url: Path.join("/", dest),
               file_id: filename,
               user_id: user_id,
               upload_batch_id: upload_batch_id,
               inner_purpose: nil
             },
             actor: current_user
           ) do
      {:ok, {:ok, image}}
    else
      {:error, reason} -> {:ok, {:error, reason}}
    end
  end

  defp normalize_upload_result({:ok, %Image{} = image}), do: {:ok, image}
  defp normalize_upload_result({:error, _reason} = error), do: error
  defp normalize_upload_result(%Image{} = image), do: {:ok, image}
  defp normalize_upload_result(other), do: {:error, other}

  defp classify_upload_error(reason) do
    message = extract_upload_error_message(reason)
    message_downcase = String.downcase(message)

    cond do
      String.contains?(message_downcase, "queue is full") ->
        {:queue_full, "Queue is busy. Please wait and check the job status shortly."}

      String.contains?(message_downcase, "timeout") ->
        {:timeout, "Request timed out. The job was marked as failed."}

      true ->
        {:other, message}
    end
  end

  defp extract_upload_error_message(%Ash.Error.Unknown{} = ash_error) do
    ash_error.errors
    |> List.first()
    |> case do
      %Ash.Error.Unknown.UnknownError{error: msg} when is_binary(msg) ->
        msg

      %{error: msg} when is_binary(msg) ->
        msg

      _ ->
        inspect(ash_error)
    end
  end

  defp extract_upload_error_message(reason) when is_binary(reason), do: reason
  defp extract_upload_error_message(reason), do: inspect(reason)

  defp put_upload_result_flash(socket, results, link_failed_count) do
    total_count = length(results)
    success_count = Enum.count(results, &match?({:ok, _}, &1))
    failure_count = total_count - success_count

    queue_full_failed_count =
      Enum.count(results, fn
        {:error, reason} ->
          match?({:queue_full, _}, classify_upload_error(reason))

        _ ->
          false
      end)

    timeout_failed_count =
      Enum.count(results, fn
        {:error, reason} ->
          match?({:timeout, _}, classify_upload_error(reason))

        _ ->
          false
      end)

    socket
    |> maybe_put_info_flash(success_count, failure_count, link_failed_count)
    |> maybe_put_queue_full_flash(queue_full_failed_count)
    |> maybe_put_timeout_flash(timeout_failed_count)
    |> maybe_put_generic_error_flash(
      failure_count - queue_full_failed_count - timeout_failed_count
    )
  end

  defp maybe_put_info_flash(socket, 0, _failure_count, _link_failed_count), do: socket

  defp maybe_put_info_flash(socket, success_count, failure_count, link_failed_count) do
    message =
      if failure_count == 0 and link_failed_count == 0 do
        "#{success_count} image(s) uploaded successfully and enqueued for processing."
      else
        "#{success_count} image(s) uploaded successfully. #{failure_count + link_failed_count} job(s) did not complete."
      end

    put_flash(socket, :info, message)
  end

  defp maybe_put_queue_full_flash(socket, count) when count > 0 do
    put_flash(
      socket,
      :error,
      "#{count} image job(s) could not be enqueued because the queue is full."
    )
  end

  defp maybe_put_queue_full_flash(socket, _count), do: socket

  defp maybe_put_timeout_flash(socket, count) when count > 0 do
    put_flash(socket, :error, "#{count} image job(s) timed out during processing.")
  end

  defp maybe_put_timeout_flash(socket, _count), do: socket

  defp maybe_put_generic_error_flash(socket, count) when count > 0 do
    put_flash(socket, :error, "#{count} image upload(s) failed. Please retry failed items.")
  end

  defp maybe_put_generic_error_flash(socket, _count), do: socket

  defp append_uploaded_photos(existing_photos, new_photos) do
    (existing_photos ++ new_photos)
    |> Enum.uniq_by(& &1.id)
  end

  attr :image, :map, required: true

  defp uploaded_photo_status_overlay(assigns) do
    ~H"""
    <div class="absolute top-2 right-2 dropdown dropdown-hover dropdown-end">
      <button
        type="button"
        tabindex="0"
        class={
          "inline-flex items-center justify-center rounded-full p-1.5 bg-base-100/90 shadow-lg " <>
            uploaded_photo_status_icon_class(@image)
        }
        title={uploaded_photo_status_label(@image)}
        aria-label={uploaded_photo_status_label(@image)}
      >
        <.uploaded_photo_status_icon status={uploaded_photo_status(@image)} />
      </button>
      <div
        tabindex="0"
        class="dropdown-content z-10 mt-1 w-56 rounded-md border border-base-300 bg-base-100 p-2 text-xs shadow-lg"
      >
        <div class="font-medium text-base-content mb-1">Processing details</div>
        <div class="flex items-center justify-between gap-2 text-base-content/80">
          <div>Search Engine</div>
          <div class={uploaded_service_status_class(@image.typesense_status)}>
            {uploaded_service_status_text(@image.typesense_status)}
          </div>
        </div>
        <div class="flex items-center justify-between gap-2 text-base-content/80 mt-1">
          <div>Vision AI</div>
          <div class={uploaded_service_status_class(@image.moondream_status)}>
            {uploaded_service_status_text(@image.moondream_status)}
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
        <.icon name="hero-check-circle" class="size-4" />
      <% :error -> %>
        <.icon name="hero-exclamation-circle" class="size-4" />
      <% :processing -> %>
        <.icon name="hero-arrow-path" class="size-4 animate-spin" />
    <% end %>
    """
  end

  defp uploaded_photo_status(%Image{} = image) do
    statuses = [image.typesense_status, image.moondream_status]

    cond do
      Enum.any?(statuses, &(&1 == "failed")) -> :error
      Enum.all?(statuses, &(&1 == "completed")) -> :success
      true -> :processing
    end
  end

  defp uploaded_photo_status_icon_class(image) do
    case uploaded_photo_status(image) do
      :success -> "text-success"
      :error -> "text-error"
      :processing -> "text-info"
    end
  end

  defp uploaded_photo_status_label(image) do
    case uploaded_photo_status(image) do
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
      nil -> "Pending"
      _ -> "Processing"
    end
  end

  defp maybe_link_note_to_photos(nil, _photos, _current_user), do: %{linked: 0, failed: 0}

  defp maybe_link_note_to_photos(_note, [], _current_user), do: %{linked: 0, failed: 0}

  defp maybe_link_note_to_photos(note, images, current_user) do
    Enum.reduce(images, %{linked: 0, failed: 0}, fn image, stats ->
      case Ash.create(
             ImageNote,
             %{
               image_id: image.id,
               note_id: note.id
             },
             action: :import,
             actor: current_user
           ) do
        {:ok, _photo_note} ->
          %{stats | linked: stats.linked + 1}

        {:error, reason} ->
          Logger.warning(
            "Failed to link image #{image.id} to note #{note.id}: #{inspect(reason)}"
          )

          %{stats | failed: stats.failed + 1}
      end
    end)
  end
end

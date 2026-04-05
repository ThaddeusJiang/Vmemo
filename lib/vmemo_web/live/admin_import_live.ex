defmodule VmemoWeb.AdminImportLive do
  use VmemoWeb, :live_view

  alias Vmemo.Admin.ImportRequest
  alias Vmemo.Repo.RLS
  alias VmemoWeb.Uploads.ImportZipWriter

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:import_zip,
        accept: ~w(.zip),
        max_entries: 1,
        max_file_size: 1024 * 1024 * 1024,
        chunk_size: 8 * 1024 * 1024,
        chunk_timeout: 120_000,
        auto_upload: true,
        writer: &import_zip_writer/3
      )
      |> assign(:form, to_form(%{}))
      |> assign(:request, nil)
      |> assign(:form_error, nil)
      |> assign(:submit_error, nil)
      |> assign(:is_submitting, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    entries = assigns.uploads.import_zip.entries

    assigns =
      assigns
      |> assign(:has_file, Enum.any?(entries))
      |> assign(:upload_progress, upload_progress(entries))
      |> assign(:upload_complete, upload_complete?(entries))

    ~H"""
    <section class="pt-10 px-4 pb-6 sm:pt-12 sm:px-6 lg:px-10 max-w-3xl mx-auto">
      <div class="card bg-base-100 border border-base-300 shadow">
        <div class="card-body space-y-2">
          <header class="space-y-1">
            <h1 class="text-xl font-semibold">Admin Import</h1>
            <p class="text-sm text-base-content/70">
              Import ZIP files exported by tag 20260120.
            </p>
          </header>

          <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-2">
            <div class="space-y-2">
              <.live_file_input
                upload={@uploads.import_zip}
                class="file-input file-input-bordered w-full"
              />

              <ul class="space-y-1">
                <li
                  :for={entry <- @uploads.import_zip.entries}
                  class="flex items-center justify-between text-sm"
                >
                  <span class="truncate">{entry.client_name}</span>
                  <button
                    type="button"
                    class="btn btn-xs btn-ghost"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                  >
                    Remove
                  </button>
                </li>
              </ul>

              <p :for={err <- upload_errors(@uploads.import_zip)} class="text-error text-sm">
                {error_to_string(err)}
              </p>

              <p :if={@form_error} class="text-error text-sm">{@form_error}</p>

              <div :if={@has_file} class="space-y-1">
                <div class="flex items-center justify-between text-xs text-base-content/70">
                  <span>Upload progress</span>
                  <span>{@upload_progress}%</span>
                </div>
                <progress
                  class="progress progress-accent w-full"
                  value={@upload_progress}
                  max="100"
                >
                </progress>
              </div>
            </div>

            <div class="py-2 flex items-center gap-2">
              <button
                type="submit"
                class="btn btn-accent"
                disabled={@is_submitting || not @has_file || not @upload_complete}
              >
                Import
              </button>
              <p :if={@submit_error} class="text-error text-sm">{@submit_error}</p>
            </div>
          </.form>

          <section :if={@request} class="pt-2 border-t border-base-300 space-y-2">
            <div class="flex flex-wrap items-center gap-2">
              <span class={status_badge_class(@request.status)}>{@request.status}</span>
              <span class="text-sm text-base-content/70">Request ID: {@request.id}</span>
            </div>

            <%= if progress = progress_value(@request.metadata) do %>
              <div class="space-y-1">
                <div class="flex items-center justify-between text-xs text-base-content/70">
                  <span>Processing progress</span>
                  <span>{progress.percent}%</span>
                </div>
                <progress class="progress progress-info w-full" value={progress.percent} max="100">
                </progress>
                <p class="text-xs text-base-content/70">{progress.stage}</p>
              </div>
            <% end %>

            <%= if @request.error_message do %>
              <p class="text-error text-sm">{@request.error_message}</p>
            <% end %>

            <%= if @request.result do %>
              <% files = result_value(@request.result, [:files, "files"], %{}) %>
              <% users = result_value(@request.result, [:users, "users"], %{}) %>
              <% photos = result_value(@request.result, [:photos, "photos"], %{}) %>
              <% notes = result_value(@request.result, [:notes, "notes"], %{}) %>
              <% photo_notes = result_value(@request.result, [:photo_notes, "photo_notes"], %{}) %>
              <% errors = result_value(@request.result, [:errors, "errors"], []) %>
              <% error_count = result_value(@request.result, [:error_count, "error_count"], 0) %>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
                <div class="border border-base-300 rounded-md p-2">
                  <p class="font-medium">Files</p>
                  <p>Copied: {result_value(files, [:copied, "copied"], 0)}</p>
                  <p>Skipped: {result_value(files, [:skipped, "skipped"], 0)}</p>
                </div>
                <div class="border border-base-300 rounded-md p-2">
                  <p class="font-medium">Users</p>
                  <p>Created: {result_value(users, [:created, "created"], 0)}</p>
                  <p>Skipped: {result_value(users, [:skipped, "skipped"], 0)}</p>
                  <p>Remapped: {result_value(users, [:remapped, "remapped"], 0)}</p>
                  <p>Failed: {result_value(users, [:failed, "failed"], 0)}</p>
                </div>
                <div class="border border-base-300 rounded-md p-2">
                  <p class="font-medium">Photos</p>
                  <p>Created: {result_value(photos, [:created, "created"], 0)}</p>
                  <p>Skipped: {result_value(photos, [:skipped, "skipped"], 0)}</p>
                  <p>Failed: {result_value(photos, [:failed, "failed"], 0)}</p>
                </div>
                <div class="border border-base-300 rounded-md p-2">
                  <p class="font-medium">Notes</p>
                  <p>Created: {result_value(notes, [:created, "created"], 0)}</p>
                  <p>Skipped: {result_value(notes, [:skipped, "skipped"], 0)}</p>
                  <p>Failed: {result_value(notes, [:failed, "failed"], 0)}</p>
                </div>
                <div class="border border-base-300 rounded-md p-2">
                  <p class="font-medium">Links</p>
                  <p>Created: {result_value(photo_notes, [:created, "created"], 0)}</p>
                  <p>Skipped: {result_value(photo_notes, [:skipped, "skipped"], 0)}</p>
                  <p>Failed: {result_value(photo_notes, [:failed, "failed"], 0)}</p>
                </div>
              </div>

              <%= if is_list(errors) and errors != [] do %>
                <div class="border border-base-300 rounded-md p-2 text-sm">
                  <p class="font-medium">
                    Errors (showing {min(length(errors), 10)} of {error_count})
                  </p>
                  <ul class="space-y-1">
                    <li :for={error <- Enum.take(errors, 10)} class="text-error">
                      {error}
                    </li>
                  </ul>
                </div>
              <% end %>
            <% end %>
          </section>
        </div>
      </div>
    </section>
    """
  end

  defp status_badge_class(status) do
    base = "badge badge-outline"

    case status do
      "pending" -> base <> " badge-ghost"
      "processing" -> base <> " badge-info"
      "completed" -> base <> " badge-success"
      "failed" -> base <> " badge-error"
      _ -> base
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, form_error: nil, submit_error: nil)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :import_zip, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    entries = socket.assigns.uploads.import_zip.entries

    cond do
      entries == [] ->
        {:noreply, assign(socket, form_error: "Please choose a ZIP file to import.")}

      not upload_complete?(entries) ->
        {:noreply, assign(socket, form_error: "Upload is still in progress.")}

      true ->
        socket = assign(socket, is_submitting: true, form_error: nil, submit_error: nil)

        uploaded =
          consume_uploaded_entries(socket, :import_zip, fn %{path: path}, entry ->
            {:ok, %{path: path, filename: entry.client_name}}
          end)

        case uploaded do
          [%{path: zip_path, filename: filename}] ->
            case RLS.with_bypass(fn ->
                   ImportRequest.create_with_zip(
                     %{source_filename: filename, zip_path: zip_path},
                     actor: nil
                   )
                 end) do
              {:ok, request} ->
                Phoenix.PubSub.subscribe(Vmemo.PubSub, "admin_import_request:#{request.id}")
                {:noreply, socket |> assign(is_submitting: false) |> assign(request: request)}

              {:error, error} ->
                {:noreply,
                 socket
                 |> assign(is_submitting: false)
                 |> assign(
                   submit_error: "Failed to create import request: #{format_error(error)}"
                 )}
            end

          _ ->
            {:noreply,
             socket
             |> assign(is_submitting: false)
             |> assign(form_error: "Failed to read ZIP file.")}
        end
    end
  end

  @impl true
  def handle_info({:import_request_updated, payload}, socket) do
    request =
      case socket.assigns.request do
        nil ->
          nil

        request ->
          %{
            request
            | status: payload.status,
              result: payload.result,
              error_message: payload.error_message,
              metadata: payload.metadata
          }
      end

    {:noreply, assign(socket, request: request)}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  defp result_value(result, keys, default) when is_map(result) do
    Enum.find_value(keys, default, fn key ->
      Map.get(result, key)
    end)
  end

  defp result_value(_result, _keys, default), do: default

  defp progress_value(metadata) when is_map(metadata) do
    case Map.get(metadata, :progress) || Map.get(metadata, "progress") do
      %{stage: stage, percent: percent} when is_binary(stage) and is_integer(percent) ->
        %{stage: stage, percent: percent}

      %{"stage" => stage, "percent" => percent} when is_binary(stage) and is_integer(percent) ->
        %{stage: stage, percent: percent}

      _ ->
        nil
    end
  end

  defp progress_value(_metadata), do: nil

  defp upload_progress(entries) do
    case entries do
      [] -> 0
      _ -> entries |> Enum.map(& &1.progress) |> Enum.max()
    end
  end

  defp upload_complete?(entries) do
    entries != [] and Enum.all?(entries, &(&1.progress == 100))
  end

  defp import_zip_writer(_name, entry, _socket) do
    dest_dir = Path.join(System.tmp_dir!(), "vmemo-import-upload")
    {ImportZipWriter, dest_dir: dest_dir, filename: entry.client_name}
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end

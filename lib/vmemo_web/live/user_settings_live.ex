defmodule VmemoWeb.UserSettingsLive do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Account
  alias Vmemo.UserSettings
  alias VmemoWeb.Uploads.ImportZipWriter

  def render(assigns) do
    import_entries = assigns.uploads.import_zip.entries

    assigns =
      assigns
      |> assign(:has_import_file, Enum.any?(import_entries))
      |> assign(:import_upload_progress, import_upload_progress(import_entries))
      |> assign(:import_upload_complete, import_upload_complete?(import_entries))

    ~H"""
    <div class="page-shell">
      <div class="content-shell content-shell-tight">
        <.header>
          {gettext("Account Settings")}
          <:subtitle>{gettext("Manage your account email and password settings")}</:subtitle>
        </.header>

        <div class="space-y-6 mx-auto w-full max-w-md ">
          <div>
            <.simple_form
              for={@email_form}
              id="email_form"
              phx-submit="update-email"
              phx-change="validate-email"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label={gettext("Email")}
                autocomplete="email"
                required
              />
              <.input
                field={@email_form[:current_password]}
                name="current_password"
                id="current_password_for_email"
                type="password"
                label={gettext("Current password")}
                autocomplete="current-password"
                value={@email_form_current_password}
                required
              />
              <:actions>
                <.button phx-disable-with={gettext("Changing...")}>{gettext("Change Email")}</.button>
              </:actions>
            </.simple_form>
          </div>
          <div>
            <.simple_form
              for={@password_form}
              id="password_form"
              action={~p"/users/update-password"}
              method="post"
              phx-change="validate-password"
              phx-submit="update-password"
              phx-trigger-action={@trigger_submit}
            >
              <input name="action" type="hidden" value="update_password" />
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                value={@current_email}
              />
              <.input
                field={@password_form[:password]}
                type="password"
                label={gettext("New password")}
                autocomplete="new-password"
                required
              />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label={gettext("Confirm new password")}
                autocomplete="new-password"
              />
              <.input
                field={@password_form[:current_password]}
                name="current_password"
                type="password"
                label={gettext("Current password")}
                id="current_password_for_password"
                autocomplete="current-password"
                value={@current_password}
                required
              />
              <:actions>
                <.button phx-disable-with={gettext("Changing...")}>
                  {gettext("Change Password")}
                </.button>
              </:actions>
            </.simple_form>
          </div>

          <div class="space-y-2">
            <div class="border border-base-300 rounded-md p-4 space-y-2">
              <h2 class="text-base font-medium">{gettext("Data Export")}</h2>
              <p class="text-sm text-base-content/70">
                {gettext("Download your images, notes, and linked files as a ZIP file.")}
              </p>
              <div class="py-2">
                <.link href={~p"/settings/export"} class="btn btn-outline">
                  {gettext("Export Data")}
                </.link>
              </div>
            </div>

            <div class="border border-base-300 rounded-md p-4 space-y-2">
              <h2 class="text-base font-medium">{gettext("Data Import")}</h2>
              <p class="text-sm text-base-content/70">
                {gettext(
                  "Upload a ZIP exported from this app. Import writes files and database records, then rebuilds search index data from Ash resources."
                )}
              </p>

              <.form
                for={@import_form}
                phx-submit="import-data"
                phx-change="validate-import"
                class="space-y-2"
              >
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
                        phx-click="cancel-import-upload"
                        phx-value-ref={entry.ref}
                      >
                        {gettext("Remove")}
                      </button>
                    </li>
                  </ul>

                  <p :for={err <- upload_errors(@uploads.import_zip)} class="text-error text-sm">
                    {error_to_string(err)}
                  </p>

                  <p :if={@import_error} class="text-error text-sm">{@import_error}</p>

                  <div :if={@has_import_file} class="space-y-1">
                    <div class="flex items-center justify-between text-xs text-base-content/70">
                      <span>{gettext("Upload progress")}</span>
                      <span>{@import_upload_progress}%</span>
                    </div>
                    <progress
                      class="progress progress-accent w-full"
                      value={@import_upload_progress}
                      max="100"
                    >
                    </progress>
                  </div>
                </div>

                <div class="py-2 flex items-center gap-2">
                  <button
                    type="submit"
                    class="btn btn-primary"
                    disabled={@is_importing || not @has_import_file || not @import_upload_complete}
                  >
                    {gettext("Import Data")}
                  </button>
                </div>
              </.form>

              <div
                :if={@import_result}
                class="border border-base-300 rounded-md p-2 text-sm space-y-1"
              >
                <p class="font-medium">{gettext("Import Result")}</p>
                <% files = result_value(@import_result, [:files, "files"], %{}) %>
                <% images = result_value(@import_result, [:images, "images"], %{}) %>
                <% notes = result_value(@import_result, [:notes, "notes"], %{}) %>
                <% image_notes = result_value(@import_result, [:image_notes, "image_notes"], %{}) %>
                <% typesense = result_value(@import_result, [:typesense, "typesense"], %{}) %>
                <% typesense_images = result_value(typesense, [:images, "images"], %{}) %>
                <% typesense_notes = result_value(typesense, [:notes, "notes"], %{}) %>
                <% errors = result_value(@import_result, [:errors, "errors"], []) %>
                <% error_count = result_value(@import_result, [:error_count, "error_count"], 0) %>
                <p>{gettext("Files copied")}: {result_value(files, [:copied, "copied"], 0)}</p>
                <p>{gettext("Files skipped")}: {result_value(files, [:skipped, "skipped"], 0)}</p>
                <p>{gettext("Images created")}: {result_value(images, [:created, "created"], 0)}</p>
                <p>{gettext("Images skipped")}: {result_value(images, [:skipped, "skipped"], 0)}</p>
                <p>{gettext("Notes created")}: {result_value(notes, [:created, "created"], 0)}</p>
                <p>{gettext("Notes skipped")}: {result_value(notes, [:skipped, "skipped"], 0)}</p>
                <p>
                  {gettext("Links created")}: {result_value(image_notes, [:created, "created"], 0)}
                </p>
                <p>
                  {gettext("Links skipped")}: {result_value(image_notes, [:skipped, "skipped"], 0)}
                </p>
                <p>
                  {gettext("Typesense images upserted")}: {result_value(
                    typesense_images,
                    [:success, "success"],
                    0
                  )}
                </p>
                <p>
                  {gettext("Typesense notes upserted")}: {result_value(
                    typesense_notes,
                    [:success, "success"],
                    0
                  )}
                </p>
                <p :if={errors != []} class="text-error">
                  {gettext("Errors")}: {error_count}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Account.update_user_email(socket.assigns.current_user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, gettext("Email changed successfully."))

        {:error, _changeset} ->
          put_flash(socket, :error, gettext("Email change link is invalid or it has expired."))
      end

    {:ok, push_navigate(socket, to: ~p"/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

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
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(%{"email" => user.email}, as: :user))
      |> assign(:password_form, to_form(%{}, as: :user))
      |> assign(:trigger_submit, false)
      |> assign(:import_form, to_form(%{}))
      |> assign(:import_result, nil)
      |> assign(:import_error, nil)
      |> assign(:is_importing, false)

    {:ok, socket}
  end

  def handle_event("validate-import", _params, socket) do
    {:noreply, assign(socket, import_error: nil)}
  end

  def handle_event("cancel-import-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :import_zip, ref)}
  end

  def handle_event("import-data", _params, socket) do
    entries = socket.assigns.uploads.import_zip.entries

    cond do
      entries == [] ->
        {:noreply, assign(socket, import_error: gettext("Please choose a ZIP file to import."))}

      not import_upload_complete?(entries) ->
        {:noreply, assign(socket, import_error: gettext("Upload is still in progress."))}

      true ->
        socket = assign(socket, is_importing: true, import_error: nil)

        uploaded =
          consume_uploaded_entries(socket, :import_zip, fn %{path: path}, entry ->
            {:ok, %{path: path, filename: entry.client_name}}
          end)

        case uploaded do
          [%{path: zip_path}] ->
            {:noreply, import_zip_data(socket, zip_path)}

          _ ->
            {:noreply,
             socket
             |> assign(:is_importing, false)
             |> assign(:import_error, gettext("Failed to read ZIP file."))}
        end
    end
  end

  def handle_event("validate-email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    email_form =
      case Account.apply_user_email(user, password, user_params) do
        {:ok, _applied_user} ->
          to_form(user_params, as: :user)

        {:error, error_map} ->
          to_form(user_params, as: :user, errors: Map.get(error_map, :errors, []))
      end

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update-email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Account.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Account.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/settings/confirm_email/#{&1}")
        )

        info = gettext("A link to confirm your email change has been sent to the new address.")
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, error_map} ->
        # Include current_password in form data so errors can be displayed
        form_data = Map.put(user_params, "current_password", password)
        email_form = to_form(form_data, as: :user, errors: Map.get(error_map, :errors, []))
        {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
    end
  end

  def handle_event("validate-password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    password_form =
      case Account.update_user_password(user, password, user_params) do
        {:ok, _user} ->
          to_form(user_params, as: :user)

        {:error, error_map} ->
          to_form(user_params, as: :user, errors: Map.get(error_map, :errors, []))
      end

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update-password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Account.update_user_password(user, password, user_params) do
      {:ok, _user} ->
        password_form = to_form(user_params, as: :user)

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, error_map} ->
        # Include current_password in form data so errors can be displayed
        form_data = Map.put(user_params, "current_password", password)
        password_form = to_form(form_data, as: :user, errors: Map.get(error_map, :errors, []))
        {:noreply, assign(socket, password_form: password_form, current_password: password)}
    end
  end

  defp import_upload_progress(entries) do
    case entries do
      [] -> 0
      _ -> entries |> Enum.map(& &1.progress) |> Enum.max()
    end
  end

  defp import_upload_complete?(entries) do
    entries != [] and Enum.all?(entries, &(&1.progress == 100))
  end

  defp import_zip_writer(_name, entry, _socket) do
    dest_dir = Path.join(System.tmp_dir!(), "vmemo-user-import-upload")
    {ImportZipWriter, dest_dir: dest_dir, filename: entry.client_name}
  end

  defp result_value(result, keys, default) when is_map(result) do
    Enum.find_value(keys, default, fn key ->
      Map.get(result, key)
    end)
  end

  defp result_value(_result, _keys, default), do: default

  defp error_to_string(:too_large), do: gettext("Too large")
  defp error_to_string(:too_many_files), do: gettext("You have selected too many files")
  defp error_to_string(:not_accepted), do: gettext("You have selected an unacceptable file type")

  defp import_zip_data(socket, zip_path) do
    case UserSettings.import_user_zip(socket.assigns.current_user.id, zip_path) do
      {:ok, result} ->
        socket
        |> assign(:is_importing, false)
        |> assign(:import_result, result)

      {:error, %{} = result} ->
        socket
        |> assign(:is_importing, false)
        |> assign(:import_result, result)
        |> assign(:import_error, gettext("Import completed with errors."))

      {:error, reason} ->
        socket
        |> assign(:is_importing, false)
        |> assign(
          :import_error,
          gettext("Import failed: %{reason}", reason: format_error(reason))
        )
    end
  end

  defp format_error(error), do: inspect(error)
end

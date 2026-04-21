defmodule VmemoWeb.UserProfileLive do
  use VmemoWeb, :live_view

  alias Vmemo.Account
  alias Vmemo.Account.UserProfileStorage

  @max_avatar_size 5 * 1024 * 1024

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-2xl p-4 sm:p-4 lg:p-4">
      <.header>
        User Profile
      </.header>

      <div class="mt-6 rounded-md border border-base-300 p-4 sm:p-6">
        <.form for={@profile_form} phx-submit="save" phx-change="validate" class="space-y-5">
          <div class="space-y-2">
            <div class="flex justify-center">
              <label
                for={@uploads.avatar.ref}
                class="avatar cursor-pointer transition-transform hover:scale-[1.02]"
              >
                <div class="w-24 rounded-full bg-base-200 ring-1 ring-base-300">
                  <.live_img_preview
                    :if={@uploads.avatar.entries != []}
                    entry={List.first(@uploads.avatar.entries)}
                    class="h-full w-full object-cover"
                  />
                  <img
                    :if={@uploads.avatar.entries == [] && @avatar_preview_url}
                    src={@avatar_preview_url}
                    alt="Avatar preview"
                    class="h-full w-full object-cover"
                  />
                  <div
                    :if={@uploads.avatar.entries == [] && !@avatar_preview_url}
                    class="flex h-full w-full items-center justify-center"
                  >
                    <span class="text-lg font-semibold">
                      {String.first(@profile_form[:name].value || "U")}
                    </span>
                  </div>
                </div>
              </label>

              <div class="grow space-y-2">
                <.live_file_input
                  upload={@uploads.avatar}
                  class="hidden"
                />
                <p :for={err <- upload_errors(@uploads.avatar)} class="text-sm text-error">
                  {avatar_upload_error(err)}
                </p>
              </div>
            </div>
          </div>

          <.input field={@profile_form[:name]} type="text" label="Name" required />

          <.input
            field={@profile_form[:language]}
            type="select"
            label="Language"
            options={[
              {"English", "en"},
              {"中文", "zh"},
              {"日本語", "ja"}
            ]}
          />

          <div :if={@has_changes} class="pt-4 flex justify-center">
            <.button class="btn-lg px-10" phx-disable-with="Saving...">Save Profile</.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    profile = Account.get_user_profile_by_user_id(user.id) || Account.default_profile(user.email)

    socket =
      socket
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: @max_avatar_size,
        auto_upload: false
      )
      |> assign(:profile, profile)
      |> assign(:profile_form, profile_form(profile))
      |> assign(:avatar_preview_url, avatar_url(user.id, profile.avatar_file_id))
      |> assign(:initial_profile_values, profile_values(profile))
      |> assign(:has_changes, false)

    {:ok, socket}
  end

  def handle_event("validate", params, socket) do
    profile_params = build_profile_params(params, socket)
    has_changes = profile_changed?(socket, profile_params)

    {:noreply,
     socket
     |> assign(:profile_form, to_form(profile_params, as: :profile))
     |> assign(:has_changes, has_changes)}
  end

  def handle_event("save", %{"profile" => params}, socket) do
    user = socket.assigns.current_user

    with {:ok, avatar_file_id} <- consume_avatar(socket, user.id),
         attrs <- build_profile_attrs(socket, params, avatar_file_id),
         {:ok, profile} <- Account.upsert_user_profile(user, attrs) do
      updated_socket =
        socket
        |> assign(:profile, profile)
        |> assign(:profile_form, profile_form(profile))
        |> assign(:avatar_preview_url, avatar_url(user.id, profile.avatar_file_id))
        |> assign(:initial_profile_values, profile_values(profile))
        |> assign(:has_changes, false)
        |> assign(:current_user_profile, profile)
        |> put_flash(:info, "Profile updated successfully.")

      {:noreply, updated_socket}
    else
      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save profile: #{format_error(error)}")}
    end
  end

  defp consume_avatar(socket, user_id) do
    consumed =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        UserProfileStorage.cp_avatar(path, user_id, entry.client_name)
      end)

    case consumed do
      [] -> {:ok, nil}
      [avatar_file_id] -> {:ok, avatar_file_id}
      _ -> {:error, "Invalid avatar upload"}
    end
  end

  defp build_profile_attrs(socket, params, nil) do
    %{
      name: String.trim(Map.get(params, "name", "")),
      language: Map.get(params, "language", "en"),
      appearance: Map.get(socket.assigns.profile, :appearance, "system"),
      avatar_file_id: Map.get(socket.assigns.profile, :avatar_file_id)
    }
  end

  defp build_profile_attrs(socket, params, avatar_file_id) do
    %{
      name: String.trim(Map.get(params, "name", "")),
      language: Map.get(params, "language", "en"),
      appearance: Map.get(socket.assigns.profile, :appearance, "system"),
      avatar_file_id: avatar_file_id
    }
  end

  defp profile_form(profile) do
    to_form(profile_values(profile), as: :profile)
  end

  defp build_profile_params(params, socket) do
    existing = socket.assigns.profile_form.params || profile_values(socket.assigns.profile)
    profile_params = Map.get(params, "profile", %{})

    existing
    |> Map.merge(Map.take(profile_params, ["name", "language"]))
    |> Map.put_new("name", "")
    |> Map.put_new("language", "en")
  end

  defp profile_values(profile) do
    %{
      "name" => profile.name,
      "language" => profile.language
    }
  end

  defp profile_changed?(socket, profile_params) do
    profile_params != socket.assigns.initial_profile_values ||
      socket.assigns.uploads.avatar.entries != []
  end

  defp avatar_url(_user_id, nil), do: nil

  defp avatar_url(user_id, avatar_file_id) do
    ~p"/storage/v1/#{user_id}/avatars/#{avatar_file_id}"
  end

  defp avatar_upload_error(:too_large), do: "Avatar is too large"
  defp avatar_upload_error(:too_many_files), do: "Only one avatar file is allowed"
  defp avatar_upload_error(:not_accepted), do: "Unsupported avatar file type"

  defp format_error(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map_join("; ", &Exception.message/1)
  end

  defp format_error(error), do: inspect(error)
end

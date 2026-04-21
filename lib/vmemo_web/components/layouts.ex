defmodule VmemoWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use VmemoWeb, :controller` and
  `use VmemoWeb, :live_view`.
  """
  use VmemoWeb, :html

  def html_lang(assigns) do
    case profile_language(assigns) do
      "zh" -> "zh-CN"
      "ja" -> "ja"
      _ -> "en"
    end
  end

  def theme_data_value(assigns) do
    case profile_appearance(assigns) do
      "light" -> "light"
      "dark" -> "dark"
      _ -> nil
    end
  end

  attr :current_user, :map, required: true
  attr :profile, :map, required: true

  def user_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div
        tabindex="0"
        role="button"
        class="avatar avatar-placeholder avatar-online hover:cursor-pointer"
      >
        <div class="bg-neutral text-neutral-content w-8 rounded-full overflow-hidden">
          <img
            :if={@profile.avatar_file_id}
            src={~p"/storage/v1/#{@current_user.id}/avatars/#{@profile.avatar_file_id}"}
            alt="User avatar"
            class="h-full w-full object-cover"
          />
          <span :if={!@profile.avatar_file_id}>{String.at(@current_user.email, 0)}</span>
        </div>
      </div>

      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box mt-1 z-[1] w-60 p-2 border border-base-300 shadow-lg"
      >
        <li>
          <.link
            href={~p"/profile"}
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-user-circle" class="size-6" /> Profile
          </.link>
        </li>
        <li>
          <.link
            href={~p"/jobs"}
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-bell" class="size-6" /> Jobs
          </.link>
        </li>
        <li>
          <.link
            href={~p"/settings"}
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-cog-6-tooth" class="size-6" /> Settings
          </.link>
        </li>
        <li>
          <.link
            href={~p"/tokens"}
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-key" class="size-6" /> Tokens
          </.link>
        </li>
        <li>
          <div class="px-3 py-2 flex items-center justify-between gap-2">
            <div class="flex items-center gap-3 min-w-0">
              <.icon name="hero-paint-brush" class="size-6 shrink-0" />
              <span class="text-[0.8125rem] leading-6 text-base-content font-semibold">
                Appearance
              </span>
            </div>
            <label class="toggle text-base-content appearance-toggle">
              <input
                type="checkbox"
                value="dark"
                checked={@profile.appearance == "dark"}
                class="theme-controller"
                aria-label="Toggle light or dark mode"
                onchange="window.updateAppearancePreference?.(this.checked)"
              />
              <svg aria-label="sun" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
                <g
                  stroke-linejoin="round"
                  stroke-linecap="round"
                  stroke-width="2"
                  fill="none"
                  stroke="currentColor"
                >
                  <circle cx="12" cy="12" r="4"></circle>
                  <path d="M12 2v2"></path>
                  <path d="M12 20v2"></path>
                  <path d="m4.93 4.93 1.41 1.41"></path>
                  <path d="m17.66 17.66 1.41 1.41"></path>
                  <path d="M2 12h2"></path>
                  <path d="M20 12h2"></path>
                  <path d="m6.34 17.66-1.41 1.41"></path>
                  <path d="m19.07 4.93-1.41 1.41"></path>
                </g>
              </svg>
              <svg
                aria-label="moon"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
              >
                <g
                  stroke-linejoin="round"
                  stroke-linecap="round"
                  stroke-width="2"
                  fill="none"
                  stroke="currentColor"
                >
                  <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"></path>
                </g>
              </svg>
            </label>
          </div>
        </li>
        <li class="border-t border-base-300 my-1"></li>
        <li>
          <.link
            href={~p"/users/logout"}
            method="delete"
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-6" /> Logout
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  defp profile_language(assigns) do
    case Map.get(assigns, :current_user_profile) do
      %{language: language} when is_binary(language) -> language
      _ -> nil
    end
  end

  defp profile_appearance(assigns) do
    case Map.get(assigns, :current_user_profile) do
      %{appearance: appearance} when is_binary(appearance) -> appearance
      _ -> nil
    end
  end

  embed_templates "layouts/*"
end

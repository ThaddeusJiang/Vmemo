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
  use Gettext, backend: VmemoWeb.Gettext

  @theme_color_light "#f8f8f8"
  @theme_color_dark "#282A36"

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

  def theme_color_value(assigns) do
    case theme_data_value(assigns) do
      "dark" -> theme_color_dark()
      _ -> theme_color_light()
    end
  end

  def theme_color_light, do: @theme_color_light
  def theme_color_dark, do: @theme_color_dark

  attr :logo_href, :string, default: "/"
  attr :cta_href, :string, default: "/login"
  attr :cta_label, :string, default: nil

  def guest_header(assigns) do
    ~H"""
    <header class="px-4 py-3 sm:px-6 lg:px-10 flex-none relative z-50">
      <div class="mx-auto flex h-14 w-full max-w-7xl items-center justify-between border-b border-base-content/12 px-1 text-sm sm:px-2">
        <a
          href={@logo_href}
          class="landing-display flex gap-2 sm:gap-4 items-center font-semibold tracking-tight"
        >
          <img src={~p"/images/logo.svg"} class="h-9 w-9 block dark:invert" />
          <span>Vmemo</span>
        </a>

        <a href={@cta_href} class="btn btn-primary btn-sm rounded-xl px-4" data-headlessui-state="">
          {@cta_label || gettext("Get started")}
        </a>
      </div>
    </header>
    """
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
        <div class="bg-neutral text-neutral-content ring ring-base-content/15 ring-offset-2 ring-offset-base-100 w-8 rounded-full overflow-hidden">
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
        class="dropdown-content elevated-popover menu bg-base-100 rounded-box mt-2 z-[90] w-60 p-2"
      >
        <li>
          <.link
            href={~p"/profile"}
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-user-circle" class="size-6" /> {gettext("Profile")}
          </.link>
        </li>
        <li>
          <.link
            href={~p"/tokens"}
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-key" class="size-6" /> {gettext("Tokens")}
          </.link>
        </li>
        <li>
          <div class="flex items-center justify-between gap-2 rounded-lg hover:bg-base-content/5 cursor-default">
            <div class="flex items-center gap-3 min-w-0">
              <.icon name="hero-paint-brush" class="size-6 shrink-0" />
              <span class="text-[0.8125rem] leading-6 text-base-content font-semibold">
                {gettext("Appearance")}
              </span>
            </div>
            <label class="swap swap-rotate text-base-content rounded-full bg-base-200/60 border border-base-300/70 cursor-pointer transition-all duration-150 hover:bg-base-200 hover:border-base-300 hover:scale-[1.03]">
              <input
                type="checkbox"
                value="dark"
                checked={@profile.appearance == "dark"}
                class="theme-controller"
                aria-label={gettext("Toggle light or dark mode")}
                onchange="window.updateAppearancePreference?.(this.checked)"
              />
              <.icon name="hero-sun" class="swap-off size-5 text-primary" />
              <.icon name="hero-moon" class="swap-on size-5" />
            </label>
          </div>
        </li>
        <li class="border-t border-base-content/20 my-2"></li>
        <li>
          <.link
            href={~p"/users/logout"}
            method="delete"
            class="text-[0.8125rem] leading-6 text-base-content font-semibold hover:text-base-content/80"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-6" /> {gettext("Logout")}
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

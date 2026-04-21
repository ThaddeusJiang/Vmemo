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

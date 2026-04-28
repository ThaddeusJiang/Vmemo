defmodule VmemoWeb.Locale do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  @supported_locales ~w(en zh ja)

  def from_profile(%{language: language}) when is_binary(language), do: normalize(language)
  def from_profile(_), do: "en"

  def normalize(locale) when locale in @supported_locales, do: locale
  def normalize(_), do: "en"

  def put_locale(%Plug.Conn{} = conn, profile) do
    locale = from_profile(profile)
    Gettext.put_locale(VmemoWeb.Gettext, locale)
    Plug.Conn.assign(conn, :locale, locale)
  end

  def put_locale(%Phoenix.LiveView.Socket{} = socket, profile) do
    locale = from_profile(profile)
    Gettext.put_locale(VmemoWeb.Gettext, locale)
    assign(socket, :locale, locale)
  end
end

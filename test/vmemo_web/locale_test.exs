defmodule VmemoWeb.LocaleTest do
  use ExUnit.Case, async: true

  alias VmemoWeb.Locale

  test "normalize/1 only allows supported locales" do
    assert Locale.normalize("en") == "en"
    assert Locale.normalize("zh") == "zh"
    assert Locale.normalize("ja") == "ja"
    assert Locale.normalize("fr") == "en"
  end

  test "from_profile/1 reads profile language and falls back" do
    assert Locale.from_profile(%{language: "ja"}) == "ja"
    assert Locale.from_profile(%{language: "fr"}) == "en"
    assert Locale.from_profile(%{}) == "en"
    assert Locale.from_profile(nil) == "en"
  end

  test "put_locale/2 assigns locale to conn" do
    conn = Plug.Test.conn("GET", "/")
    conn = Locale.put_locale(conn, %{language: "zh"})

    assert conn.assigns.locale == "zh"
  end

  test "put_locale/2 assigns locale to liveview socket" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    socket = Locale.put_locale(socket, %{language: "ja"})

    assert socket.assigns.locale == "ja"
  end
end

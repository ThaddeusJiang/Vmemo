defmodule VmemoWeb.GlobalAskAiDrawerTest do
  use VmemoWeb.ConnCase, async: true

  import Vmemo.AccountFixtures
  import Phoenix.LiveViewTest

  describe "global ask ai drawer" do
    test "shows global ask ai launcher for authenticated live pages", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/home")

      assert html =~ ~s(id="global-ask-ai-launch")
      assert html =~ ~s(id="global-ask-ai-close")
      refute html =~ "<iframe"
    end

    test "does not render duplicate global launcher inside chat page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/chat")

      refute html =~ ~s(id="global-ask-ai-launch")
    end
  end

  test "does not show global ask ai launcher for guest pages", %{conn: conn} do
    html = get(conn, ~p"/") |> html_response(200)
    refute html =~ ~s(id="global-ask-ai-launch")
  end
end

defmodule VmemoWeb.TokenLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures
  import VmemoWeb.ApiFixtures

  describe "Index - show token list" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, conn: conn, user: user}
    end

    test "show empty token list", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "Tokens"
      assert html =~ "Total Tokens"
      assert html =~ "0"
    end

    test "show token stats", %{conn: conn, user: user} do
      # create a test token
      create_test_token(user)

      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "Total Tokens"
      assert html =~ "Active Tokens"
      assert html =~ "Expired Tokens"
    end

    test "can navigate to create page", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/tokens")

      assert has_element?(index_live, "a[href='#{~p"/tokens/new"}']")
    end
  end

  describe "Form - create token" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, conn: conn, user: user}
    end

    test "show create form", %{conn: conn} do
      {:ok, _form_live, html} = live(conn, ~p"/tokens/new")

      assert html =~ "Create API Token"
      assert html =~ "Token Name"
      assert html =~ "Expiration"
    end
  end
end

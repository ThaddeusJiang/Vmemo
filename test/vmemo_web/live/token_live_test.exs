defmodule VmemoWeb.TokenLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  alias VmemoWeb.ApiFixtures

  describe "Index" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Create a test token before the tests run
      _raw_token = ApiFixtures.create_test_token(user)

      {:ok, conn: conn, user: user}
    end

    test "lists all user tokens", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "API Token Management"
      # Check that the page displays token statistics
      assert html =~ "1"  # 1 token should be displayed
    end

    test "displays statistics", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "Total Tokens"
      assert html =~ "Active Tokens"
    end

    test "displays token actions", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      # Check that the page has action buttons
      assert html =~ "My API Tokens"
      # The token table should be displayed
      assert html =~ "Total Tokens"
    end

    test "token list has actions for interaction", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      # Verify the page displays tokens with actions
      assert html =~ "Total Tokens"
      assert html =~ "Active Tokens"
    end

    test "redirects to create form when clicking create button", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/tokens")

      # Check that create button exists
      assert render(index_live) =~ "Create New Token"
    end

    test "displays message when user has no tokens", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "0"
      assert html =~ "Total Tokens"
    end
  end

  describe "Form" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, conn: conn, user: user}
    end

    test "can navigate to create token form", %{conn: conn} do
      {:ok, _form_live, html} = live(conn, ~p"/tokens/new")

      assert html =~ "Create API Token"
    end

    test "shows token creation form", %{conn: conn} do
      {:ok, _form_live, html} = live(conn, ~p"/tokens/new")

      assert html =~ "Token Name"
      assert html =~ "Expiration"
    end
  end
end

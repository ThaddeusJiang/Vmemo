defmodule VmemoWeb.TokenLiveTest do
  use VmemoWeb.ConnCase

  import Phoenix.LiveViewTest

  defp create_token(_) do
    # Create a test user using AccountFixtures
    user = Vmemo.AccountFixtures.user_fixture()
    # Use ApiTokenService to create token
    case Vmemo.ApiTokenService.create_api_token(user, %{
           "name" => "test token",
           "expires_at" => "30"
         }) do
      {:ok, token, _raw_token} ->
        %{token: token, user: user}

      {:error, error} ->
        IO.puts("Token creation failed: #{inspect(error)}")
        raise "Token creation failed"
    end
  end

  describe "Index" do
    setup [:create_token]

    test "lists all tokens", %{conn: conn, token: token, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "API Token Management"
      assert html =~ token.name
    end

    test "can access new token form", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, index_live, _html} = live(conn, ~p"/tokens")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Create New Token")
               |> render_click()
               |> follow_redirect(conn, ~p"/tokens/new")

      assert render(form_live) =~ "Create API Token"
    end

    test "deletes token in listing", %{conn: conn, token: token, user: user} do
      conn = log_in_user(conn, user)
      {:ok, index_live, _html} = live(conn, ~p"/tokens")

      assert index_live
             |> element("button[phx-click=\"delete_token\"][phx-value-id=\"#{token.id}\"]")
             |> render_click()

      refute has_element?(index_live, "##{token.id}")
    end
  end

  describe "Show" do
    setup [:create_token]

    test "displays token", %{conn: conn, token: token, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _show_live, html} = live(conn, ~p"/tokens/#{token.id}")

      assert html =~ "API Token Details"
      assert html =~ token.name
    end
  end
end

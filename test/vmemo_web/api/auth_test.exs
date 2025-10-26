defmodule VmemoWeb.Api.V1.AuthTest do
  @moduledoc """
  API Authentication Tests
  """

  use VmemoWeb.ConnCase

  alias Vmemo.Account
  alias Vmemo.ApiTokenService

  @test_email "test@mail.com"
  @test_password "password123456"
  @test_token "test123456"

  setup %{conn: conn} do
    # Ensure test user exists
    user = ensure_test_user()

    # Create API token if not exists
    ensure_api_token(user)

    {:ok, conn: conn, user: user}
  end

  describe "API Authentication" do
    test "accepts valid token for API access", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@test_token}")
        |> get(~p"/api/v1/photos/123")

      # Should not return 401 (404 or 200 is OK)
      refute conn.status == 401
    end

    test "rejects invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token_12345")
        |> get(~p"/api/v1/photos/123")

      assert conn.status == 401
      assert %{"status" => "error"} = json_response(conn, 401)
      assert %{"error" => error} = json_response(conn, 401)
      assert error["code"] == "UNAUTHORIZED"
    end

    test "rejects missing token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/photos/123")

      assert conn.status == 401
      assert %{"status" => "error"} = json_response(conn, 401)
      assert %{"error" => error} = json_response(conn, 401)
      assert error["code"] == "UNAUTHORIZED"
    end

    test "rejects token without Bearer prefix", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", @test_token)
        |> get(~p"/api/v1/photos/123")

      assert conn.status == 401
    end

    test "verifies token allows access to protected endpoint", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@test_token}")
        |> assign(:current_ash_user, user)
        |> get(~p"/api/v1/photos")

      # Should not be unauthorized
      refute conn.status == 401
    end
  end

  # Helper functions

  defp ensure_test_user do
    case Account.get_ash_user_by_email(@test_email) do
      nil ->
        {:ok, user} =
          Account.register_user(%{
            email: @test_email,
            password: @test_password
          })

        user

      user ->
        user
    end
  end

  defp ensure_api_token(_user) do
    # Check if token "test123456" exists in database
    # For now, we assume the token is manually created
    # In a real implementation, we would verify the token exists
    :ok
  end
end

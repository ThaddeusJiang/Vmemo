defmodule VmemoWeb.Api.V1.AuthTest do
  @moduledoc """
  API 认证测试
  """

  use VmemoWeb.ConnCase, async: true

  import Vmemo.AccountFixtures
  import VmemoWeb.ApiFixtures

  describe "API Token Authentication" do
    setup %{conn: conn} do
      user = user_fixture()
      raw_token = create_test_token(user)

      {:ok, conn: conn, user: user, raw_token: raw_token}
    end

    test "accepts valid token", %{conn: conn, raw_token: raw_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> get(~p"/api/v1/images/1")

      # Should not be unauthorized (404 is OK for non-existent image)
      refute conn.status == 401
      refute conn.status == 403
    end

    test "rejects missing token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/images/1")

      assert conn.status == 401

      assert json_response(conn, 401) == %{
               "status" => "error",
               "error" => %{
                 "code" => "UNAUTHORIZED",
                 "message" => "Invalid or missing API token"
               }
             }
    end

    test "rejects invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token_12345")
        |> get(~p"/api/v1/images/1")

      assert conn.status == 401
    end

    test "rejects token without Bearer prefix", %{conn: conn, raw_token: raw_token} do
      conn =
        conn
        |> put_req_header("authorization", raw_token)
        |> get(~p"/api/v1/images/1")

      assert conn.status == 401
    end

    test "rejects empty Bearer token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ")
        |> get(~p"/api/v1/images/1")

      assert conn.status == 401
    end

    test "rejects malformed authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "NotBearer token123")
        |> get(~p"/api/v1/images/1")

      assert conn.status == 401
    end
  end
end

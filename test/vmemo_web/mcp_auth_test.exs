defmodule VmemoWeb.McpAuthTest do
  use VmemoWeb.ConnCase, async: true

  import Vmemo.AccountFixtures
  import VmemoWeb.ApiFixtures

  alias VmemoWeb.McpAuth

  describe "MCP bearer token authentication" do
    setup %{conn: conn} do
      user = user_fixture()
      raw_token = create_test_token(user)
      conn = %{conn | method: "POST"}

      {:ok, conn: conn, user: user, raw_token: raw_token}
    end

    test "sets current user and Ash actor for valid bearer token", %{
      conn: conn,
      user: user,
      raw_token: raw_token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> McpAuth.call([])

      refute conn.halted
      assert conn.assigns.current_user.id == user.id
      assert Ash.PlugHelpers.get_actor(conn).id == user.id
    end

    test "rejects missing bearer token", %{conn: conn} do
      conn = McpAuth.call(conn, [])

      assert conn.halted
      assert conn.status == 401

      assert Jason.decode!(conn.resp_body) == %{
               "statusCode" => 401,
               "statusMessage" => "Unauthorized",
               "message" => "Invalid or missing API token"
             }
    end

    test "rejects invalid bearer token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> McpAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects unauthenticated MCP POST requests", %{conn: conn} do
      conn =
        post(conn, ~p"/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "test", "version" => "1.0"}
          }
        })

      assert conn.status == 401
    end

    test "allows authenticated MCP initialize requests", %{conn: conn, raw_token: raw_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "test", "version" => "1.0"}
          }
        })

      assert conn.status == 200
      assert get_resp_header(conn, "mcp-session-id") != []
      refute json_response(conn, 200)["error"]
    end
  end
end

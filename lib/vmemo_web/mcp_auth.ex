defmodule VmemoWeb.McpAuth do
  @moduledoc """
  Bearer token authentication for the MCP server.

  MCP image tools require an Ash actor, so unauthenticated requests are rejected
  before they reach AshAi tool execution.
  """

  import Plug.Conn

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only support StreamableHttp (POST requests), reject GET requests
    # GET requests are used for SSE endpoint discovery, but we only support StreamableHttp
    if conn.method == "GET" do
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(
        405,
        Jason.encode!(%{
          error: "Method Not Allowed",
          message:
            "This MCP server only supports StreamableHttp transport. Please use POST requests instead of GET."
        })
      )
      |> halt()
    else
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token] when token != "" ->
          verify_token(conn, token)

        _ ->
          unauthorized(conn)
      end
    end
  end

  defp verify_token(conn, token) do
    case Vmemo.Account.ApiToken.verify_api_token(token) do
      {:ok, api_token} ->
        conn
        |> assign(:current_api_token, api_token)
        |> assign(:current_user, api_token.user)
        |> Ash.PlugHelpers.set_actor(api_token.user)

      {:error, reason} ->
        Logger.warning("MCP API token verification failed: #{reason}")
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(
      401,
      Jason.encode!(%{
        statusCode: 401,
        statusMessage: Plug.Conn.Status.reason_phrase(401),
        message: "Invalid or missing API token"
      })
    )
    |> halt()
  end
end

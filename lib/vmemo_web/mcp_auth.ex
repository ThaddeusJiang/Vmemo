defmodule VmemoWeb.McpAuth do
  @moduledoc """
  Bearer token authentication for the MCP server.

  MCP image tools require an Ash actor, so unauthenticated requests are rejected
  before they reach AshAi tool execution.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  require Logger
  alias Ash.PlugHelpers
  alias Vmemo.Account.ApiToken

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only support StreamableHttp (POST requests), reject GET requests
    # GET requests are used for SSE endpoint discovery, but we only support StreamableHttp
    if conn.method == "GET" do
      conn
      |> put_status(:method_not_allowed)
      |> json(%{
        error: "Method Not Allowed",
        message:
          "This MCP server only supports StreamableHttp transport. Please use POST requests instead of GET."
      })
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
    case ApiToken.verify_api_token(token) do
      {:ok, api_token} ->
        conn
        |> assign(:current_api_token, api_token)
        |> assign(:current_user, api_token.user)
        |> PlugHelpers.set_actor(api_token.user)

      {:error, reason} ->
        Logger.warning("MCP API token verification failed: #{reason}")
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      statusCode: 401,
      statusMessage: Plug.Conn.Status.reason_phrase(401),
      message: "Invalid or missing API token"
    })
    |> halt()
  end
end

defmodule VmemoWeb.McpAuth do
  @moduledoc """
  Optional authentication for MCP server.

  Allows unauthenticated access, but sets actor if API token is provided.
  This allows public tools to work while still supporting authenticated tools.
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
          # Allow unauthenticated access for public tools
          conn
      end
    end
  end

  defp verify_token(conn, token) do
    case Vmemo.ApiTokenService.verify_api_token(token) do
      {:ok, api_token} ->
        # Set actor if token is valid
        # Use Ash.PlugHelpers.set_actor/2 to store actor in conn.private[:ash][:actor]
        conn
        |> assign(:current_api_token, api_token)
        |> assign(:current_user, api_token.user)
        |> Ash.PlugHelpers.set_actor(api_token.user)

      {:error, reason} ->
        Logger.warning("MCP API token verification failed: #{reason}")
        # Still allow connection, but without actor
        conn
    end
  end
end

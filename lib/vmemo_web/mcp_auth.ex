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
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when token != "" ->
        verify_token(conn, token)

      _ ->
        # Allow unauthenticated access for public tools
        conn
    end
  end

  defp verify_token(conn, token) do
    case Vmemo.ApiTokenService.verify_api_token(token) do
      {:ok, api_token} ->
        # Set actor if token is valid
        # Ash.PlugHelpers.get_actor looks for conn.assigns[:actor]
        conn
        |> assign(:current_api_token, api_token)
        |> assign(:current_ash_user, api_token.ash_user)
        |> assign(:actor, api_token.ash_user)

      {:error, reason} ->
        Logger.warning("MCP API token verification failed: #{reason}")
        # Still allow connection, but without actor
        conn
    end
  end
end

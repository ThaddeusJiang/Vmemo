defmodule VmemoWeb.ApiAuth do
  @moduledoc """
  API Token authentication module

  Handles Bearer Token authentication for API requests
  """

  import Plug.Conn
  import Phoenix.Controller

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        if token != "", do: verify_token(conn, token), else: unauthorized(conn)

      _ ->
        unauthorized(conn)
    end
  end

  defp verify_token(conn, token) do
    case Vmemo.Account.ApiTokens.verify_api_token(token) do
      {:ok, api_token} ->
        # Attach user info to the connection
        conn
        |> assign(:current_api_token, api_token)
        |> assign(:current_user, api_token.user)

      {:error, reason} ->
        Logger.warning("API token verification failed: #{reason}")
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(401)
    |> json(%{
      status: "error",
      error: %{
        code: "UNAUTHORIZED",
        message: "Invalid or missing API token"
      }
    })
    |> halt()
  end
end

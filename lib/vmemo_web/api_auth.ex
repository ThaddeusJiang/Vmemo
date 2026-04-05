defmodule VmemoWeb.ApiAuth do
  @moduledoc """
  API Token 认证模块

  处理 API 请求的 Bearer Token 认证
  """

  import Plug.Conn
  import Phoenix.Controller

  require Logger
  alias Vmemo.Repo.RLS

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
    case Vmemo.ApiTokenService.verify_api_token(token) do
      {:ok, api_token} ->
        # 将用户信息添加到连接中
        RLS.put_actor(api_token.user)

        conn
        |> assign(:current_api_token, api_token)
        |> assign(:current_user, api_token.user)

      {:error, reason} ->
        Logger.warning("API token verification failed: #{reason}")
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    RLS.clear_actor()

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

defmodule VmemoWeb.AdminSessionController do
  use VmemoWeb, :controller

  alias VmemoWeb.AdminAuth

  @doc """
  处理管理员登录请求

  验证 token 并创建管理员 session
  """
  def create(conn, %{"admin" => %{"token" => token}}) do
    if AdminAuth.verify_admin_token(token) do
      conn
      |> AdminAuth.put_admin_in_session(token)
      |> put_flash(:info, "管理员登录成功")
      |> redirect(to: AdminAuth.admin_signed_in_path(conn))
    else
      conn
      |> put_flash(:error, "无效的管理员 token")
      |> redirect(to: ~p"/admin/login")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "请提供管理员 token")
    |> redirect(to: ~p"/admin/login")
  end

  @doc """
  处理管理员登出请求
  """
  def delete(conn, _params) do
    conn
    |> AdminAuth.log_out_admin()
  end
end

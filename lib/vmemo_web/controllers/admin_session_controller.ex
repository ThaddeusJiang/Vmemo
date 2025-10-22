defmodule VmemoWeb.AdminSessionController do
  use VmemoWeb, :controller

  alias VmemoWeb.AdminAuth

  def create(conn, %{"admin" => %{"token" => token}}) do
    if AdminAuth.verify_admin_token(token) do
      conn
      |> AdminAuth.put_admin_in_session(token)
      |> put_flash(:info, "Admin login successful")
      |> redirect(to: AdminAuth.admin_signed_in_path(conn))
    else
      conn
      |> put_flash(:error, "Invalid admin token")
      |> redirect(to: ~p"/admin/login")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Please provide admin token")
    |> redirect(to: ~p"/admin/login")
  end

  def delete(conn, _params) do
    conn
    |> AdminAuth.log_out_admin()
  end
end

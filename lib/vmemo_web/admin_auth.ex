defmodule VmemoWeb.AdminAuth do
  @moduledoc """
  Admin authentication module

  Provides independent admin authentication functionality, not dependent on existing user authentication system.
  Uses simple token verification mechanism.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]
  import Phoenix.Component, only: [assign: 2]

  # Session key for admin authentication
  @admin_session_key "admin_token"

  @doc """
  Check if admin is logged in
  """
  def admin_logged_in?(conn) do
    !!get_session(conn, @admin_session_key)
  end

  @doc """
  Verify admin token
  """
  def verify_admin_token(token) do
    configured_token = Application.get_env(:vmemo, :admin_token)
    token == configured_token
  end

  def put_admin_in_session(conn, token) do
    conn
    |> put_session(@admin_session_key, token)
    |> put_session(:live_socket_id, "admin_sessions:#{Base.url_encode64(token)}")
  end

  def clear_admin_session(conn) do
    conn
    |> delete_session(@admin_session_key)
    |> delete_session(:live_socket_id)
  end

  @doc """
  Plug function: require admin authentication
  """
  def require_admin(conn, _opts) do
    if admin_logged_in?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "Admin privileges required to access this page")
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end

  @doc """
  LiveView on_mount callback: ensure admin is authenticated
  """
  def on_mount(:ensure_admin, _params, session, socket) do
    if session[@admin_session_key] do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Admin privileges required to access this page")
        |> redirect(to: "/admin/login")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_admin_is_authenticated, _params, session, socket) do
    socket = assign(socket, current_user: nil, current_scope: nil)

    if session[@admin_session_key] do
      {:halt, redirect(socket, to: "/admin")}
    else
      {:cont, socket}
    end
  end

  def log_out_admin(conn) do
    conn
    |> clear_admin_session()
    |> redirect(to: "/admin/login")
  end

  def admin_signed_in_path(_conn), do: "/admin"

  @doc """
  For routes that require admin to be unauthenticated
  """
  def redirect_if_admin_is_authenticated(conn, _opts) do
    if admin_logged_in?(conn) do
      conn
      |> redirect(to: admin_signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end
end

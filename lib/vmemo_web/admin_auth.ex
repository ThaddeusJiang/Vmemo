defmodule VmemoWeb.AdminAuth do
  @moduledoc """
  管理员认证模块

  提供独立的管理员认证功能，不依赖现有的用户认证系统。
  使用简单的 token 验证机制。
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]
  import Phoenix.LiveView, except: [redirect: 2, put_flash: 3]
  import Phoenix.Component, only: [assign: 2, assign: 3]

  # Session key for admin authentication
  @admin_session_key "admin_token"

  @doc """
  检查管理员是否已登录

  从 session 中获取 admin_token，如果存在则说明已登录
  """
  def admin_logged_in?(conn) do
    !!get_session(conn, @admin_session_key)
  end

  @doc """
  验证管理员 token

  将用户输入的 token 与配置中的 admin_token 进行比较
  """
  def verify_admin_token(token) do
    configured_token = Application.get_env(:vmemo, :admin_token)
    token == configured_token
  end

  @doc """
  将管理员 token 存储到 session 中
  """
  def put_admin_in_session(conn, token) do
    conn
    |> put_session(@admin_session_key, token)
    |> put_session(:live_socket_id, "admin_sessions:#{Base.url_encode64(token)}")
  end

  @doc """
  从 session 中清除管理员认证信息
  """
  def clear_admin_session(conn) do
    conn
    |> delete_session(@admin_session_key)
    |> delete_session(:live_socket_id)
  end

  @doc """
  Plug 函数：要求管理员认证

  如果管理员未登录，重定向到登录页面
  """
  def require_admin(conn, _opts) do
    if admin_logged_in?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "需要管理员权限才能访问此页面")
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end

  @doc """
  LiveView on_mount 回调：确保管理员已认证

  用于 LiveView 中的管理员权限检查
  """
  def on_mount(:ensure_admin, _params, session, socket) do
    if session[@admin_session_key] do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "需要管理员权限才能访问此页面")
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

  @doc """
  登出管理员
  """
  def log_out_admin(conn) do
    conn
    |> clear_admin_session()
    |> redirect(to: "/admin/login")
  end

  @doc """
  获取管理员登录后的重定向路径
  """
  def admin_signed_in_path(_conn), do: "/admin"

  @doc """
  用于需要管理员未认证的路由

  如果管理员已登录，重定向到管理后台
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

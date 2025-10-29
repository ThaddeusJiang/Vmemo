defmodule VmemoWeb.AshUserAuth do
  use VmemoWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Vmemo.Account.AshUser

  @doc """
  Logs the Ash user in.
  """
  def log_in_ash_user(conn, ash_user, params \\ %{}) do
    # Get user_return_to BEFORE renewing session (which clears it)
    user_return_to = get_session(conn, :user_return_to)

    # Delete old session token if it exists (important for password updates)
    if old_token = get_session(conn, :user_token) do
      delete_ash_user_session_token(old_token)
    end

    # 使用 Ash Authentication 的 token 系统
    # Generate a NEW token for this login
    token = generate_ash_user_session_token(ash_user)

    conn
    |> Phoenix.Controller.fetch_flash()
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> maybe_put_return_flash(user_return_to)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_put_return_flash(conn, user_return_to) when is_binary(user_return_to) do
    # Only set "Welcome back!" if there's no existing flash message
    case Map.get(conn.assigns, :flash) do
      nil ->
        put_flash(conn, :info, "Welcome back!")

      flash ->
        case Phoenix.Flash.get(flash, :info) do
          nil -> put_flash(conn, :info, "Welcome back!")
          _ -> conn
        end
    end
  end

  defp maybe_put_return_flash(conn, _), do: conn

  defp generate_ash_user_session_token(ash_user) do
    # 使用 Ash Authentication JWT 生成 session token
    case AshAuthentication.Jwt.token_for_user(ash_user) do
      {:ok, token, _claims} ->
        token

      {:ok, token} ->
        token

      _ ->
        # 如果失败，生成一个简单的 session token
        :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    end
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, "_vmemo_web_user_remember_me", token,
      sign: true,
      max_age: 60 * 60 * 24 * 60,
      same_site: "Lax"
    )
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  @doc """
  Logs the Ash user out.
  """
  def log_out_ash_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && delete_ash_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      VmemoWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_session(:user_token)
    |> delete_resp_cookie("_vmemo_web_user_remember_me")
    |> redirect(to: ~p"/")
  end

  defp delete_ash_user_session_token(token) do
    # 使用 Ash Authentication JWT 验证 token
    case AshAuthentication.Jwt.verify(token, AshUser) do
      {:ok, claims, _resource} ->
        # 从 claims 中获取 jti (token ID) 并撤销 token
        case Map.get(claims, "jti") do
          nil ->
            :ok

          jti ->
            # 删除 token 记录
            case Ash.get(Vmemo.Account.AshUserToken, jti) do
              {:ok, token_record} -> Ash.destroy(token_record)
              _ -> :ok
            end
        end

      _ ->
        :ok
    end
  end

  @doc """
  Authenticates the Ash user by looking into the session.
  """
  def fetch_current_ash_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    ash_user = user_token && get_ash_user_by_session_token(user_token)
    assign(conn, :current_ash_user, ash_user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: ["_vmemo_web_user_remember_me"])

      if token = conn.cookies["_vmemo_web_user_remember_me"] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  defp get_ash_user_by_session_token(token) do
    # 使用 Ash Authentication JWT 验证 token
    case AshAuthentication.Jwt.verify(token, AshUser) do
      {:ok, claims, _resource} ->
        # 从 claims 中获取用户 ID
        case Map.get(claims, "sub") do
          nil ->
            nil

          "ash_user?id=" <> user_id ->
            case Ash.get(AshUser, user_id) do
              {:ok, ash_user} -> ash_user
              _ -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def require_authenticated_ash_user(conn, _opts) do
    if conn.assigns[:current_ash_user] do
      conn
    else
      conn
      |> Phoenix.Controller.fetch_flash()
      |> put_flash(:error, "You must sign in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_ash_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_ash_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  @doc """
  Mounts the current Ash user.
  """
  def on_mount(:mount_current_ash_user, _params, session, socket) do
    {:cont, mount_current_ash_user(socket, session)}
  end

  def on_mount(:ensure_authenticated_ash_user, _params, session, socket) do
    socket = mount_current_ash_user(socket, session)

    if socket.assigns.current_ash_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must sign in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_ash_user_is_authenticated, _params, session, socket) do
    socket = mount_current_ash_user(socket, session)

    if socket.assigns.current_ash_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_ash_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_ash_user, fn ->
      if user_token = session["user_token"] do
        get_ash_user_by_session_token(user_token)
      end
    end)
  end

  defp signed_in_path(_conn), do: ~p"/home"
end

defmodule VmemoWeb.UserAuth do
  use VmemoWeb, :verified_routes
  use AshAuthentication.Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller, except: [redirect: 2, put_flash: 3]
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign_new: 3]

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn ->
      with {:ok, user} <- AshAuthentication.Plug.Helpers.retrieve_from_session(session, :vmemo) do
        user
      else
        _ -> nil
      end
    end)
    {:cont, socket}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn ->
      with {:ok, user} <- AshAuthentication.Plug.Helpers.retrieve_from_session(session, :vmemo) do
        user
      else
        _ -> nil
      end
    end)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must sign in to access this page.")
        |> redirect(to: ~p"/sign-in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn ->
      with {:ok, user} <- AshAuthentication.Plug.Helpers.retrieve_from_session(session, :vmemo) do
        user
      else
        _ -> nil
      end
    end)

    if socket.assigns.current_user do
      {:halt, redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must sign in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/sign-in")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn_or_socket), do: ~p"/home"
end

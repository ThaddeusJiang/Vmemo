defmodule VmemoWeb.UserSessionController do
  use VmemoWeb, :controller

  alias Vmemo.Account.User
  alias VmemoWeb.UserAuth

  def create(conn, %{"_action" => action, "user" => user_params}) do
    %{"email" => email, "password" => password} = user_params
    strategy = AshAuthentication.Info.strategy!(User, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => email,
           "password" => password
         }) do
      {:ok, user} ->
        # 使用 UserAuth 处理登录，传递 user_params 以支持 remember_me
        conn
        |> maybe_put_action_flash(action)
        |> log_in_with_action(user, user_params, action)

      {:error, _reason} ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/login")
    end
  end

  def create(conn, %{"user" => user_params} = params) do
    # Extract _action from params or query_params (e.g., from query string)
    action = params["_action"] || conn.query_params["_action"]
    create(conn, %{"_action" => action, "user" => user_params})
  end

  defp log_in_with_action(conn, user, user_params, "password_updated") do
    # For password_updated, we need to redirect to settings page
    # Store the redirect path in session before calling log_in_user
    conn
    |> put_session(:user_return_to, ~p"/settings")
    |> UserAuth.log_in_user(user, user_params)
  end

  defp log_in_with_action(conn, user, user_params, _action) do
    UserAuth.log_in_user(conn, user, user_params)
  end

  defp maybe_put_action_flash(conn, "registered") do
    put_flash(conn, :info, "Account created successfully!")
  end

  defp maybe_put_action_flash(conn, "password_updated") do
    put_flash(conn, :info, "Password updated successfully!")
  end

  defp maybe_put_action_flash(conn, _), do: conn

  def delete(conn, params) do
    # 支持 return_to 参数，退出后返回指定页面
    return_to = params["return_to"] || conn.query_params["return_to"] || ~p"/"

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user(return_to)
  end
end

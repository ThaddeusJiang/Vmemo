defmodule VmemoWeb.AshUserSessionController do
  use VmemoWeb, :controller

  alias VmemoWeb.AshUserAuth
  alias Vmemo.Account.AshUser

  def create(conn, %{"_action" => action, "user" => user_params}) do
    %{"email" => email, "password" => password} = user_params
    strategy = AshAuthentication.Info.strategy!(AshUser, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => email,
           "password" => password
         }) do
      {:ok, ash_user} ->
        # 使用 AshUserAuth 处理登录，传递 user_params 以支持 remember_me
        conn
        |> maybe_put_action_flash(action)
        |> log_in_with_action(ash_user, user_params, action)

      {:error, _reason} ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def create(conn, %{"user" => user_params} = params) do
    # Extract _action from params or query_params (e.g., from query string)
    action = params["_action"] || conn.query_params["_action"]
    create(conn, %{"_action" => action, "user" => user_params})
  end

  defp log_in_with_action(conn, ash_user, user_params, "password_updated") do
    # For password_updated, we need to redirect to settings page
    # Store the redirect path in session before calling log_in_ash_user
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> AshUserAuth.log_in_ash_user(ash_user, user_params)
  end

  defp log_in_with_action(conn, ash_user, user_params, _action) do
    AshUserAuth.log_in_ash_user(conn, ash_user, user_params)
  end

  defp maybe_put_action_flash(conn, "registered") do
    put_flash(conn, :info, "Account created successfully!")
  end

  defp maybe_put_action_flash(conn, "password_updated") do
    put_flash(conn, :info, "Password updated successfully!")
  end

  defp maybe_put_action_flash(conn, _), do: conn

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AshUserAuth.log_out_ash_user()
  end
end

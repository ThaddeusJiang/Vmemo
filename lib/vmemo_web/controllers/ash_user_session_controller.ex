defmodule VmemoWeb.AshUserSessionController do
  use VmemoWeb, :controller

  alias VmemoWeb.AshUserAuth
  alias Vmemo.Account.AshUser

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    strategy = AshAuthentication.Info.strategy!(AshUser, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => email,
           "password" => password
         }) do
      {:ok, ash_user} ->
        # 使用 AshUserAuth 处理登录
        conn
        |> AshUserAuth.log_in_ash_user(ash_user, %{})

      {:error, _reason} ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AshUserAuth.log_out_ash_user()
  end
end

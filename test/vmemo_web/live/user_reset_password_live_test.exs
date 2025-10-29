defmodule VmemoWeb.UserResetPasswordLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  alias Vmemo.Account

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Account.deliver_ash_user_reset_password_instructions(user, url)
      end)

    %{token: token, user: user}
  end

  describe "Reset password page" do
    test "renders reset password with valid token", %{conn: conn, token: token} do
      # TODO: 今后编写
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      {:error, {:redirect, to}} = live(conn, ~p"/users/reset_password/invalid")

      assert to == %{
               flash: %{"error" => "Reset password link is invalid or it has expired."},
               to: ~p"/"
             }
    end

    test "renders errors for invalid data", %{conn: conn, token: token} do
      # TODO: 今后编写
    end
  end

  describe "Reset Password" do
    test "resets password once", %{conn: conn, token: token, user: user} do
      # TODO: 今后编写
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      # TODO: 今后编写
    end
  end

  describe "Reset password navigation" do
    test "redirects to login page when the Sign in button is clicked", %{conn: conn, token: token} do
      # TODO: 今后编写
    end

    test "redirects to registration page when the Register button is clicked", %{
      conn: conn,
      token: token
    } do
      # TODO: 今后编写
    end
  end
end

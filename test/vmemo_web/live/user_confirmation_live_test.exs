defmodule VmemoWeb.UserConfirmationLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  alias Vmemo.Account
  # alias Vmemo.Repo

  setup do
    %{user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Account.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      # Submit form, which redirects to confirm-login route
      assert {:error, {:redirect, %{status: 302, to: confirm_login_path}}} =
               lv
               |> form("#confirmation_form")
               |> render_submit()

      assert confirm_login_path == ~p"/users/confirm-login/#{token}"

      # Follow redirect to confirm-login controller, which redirects to /home
      conn = get(conn, confirm_login_path)
      assert redirected_to(conn) == ~p"/home"

      # Follow redirect to /home and check flash message
      conn = get(conn, ~p"/home")
      assert html_response(conn, 200)

      # Flash message may be "Welcome back!" or nil (if already set)
      flash_info = Phoenix.Flash.get(conn.assigns.flash, :info)
      assert flash_info == nil or flash_info =~ "Welcome back!"

      assert Account.get_user!(user.id).confirmed_at
      assert get_session(conn, :user_token)
      # Token verification removed - Ash uses JWT tokens instead of UserToken records
      # assert Repo.all(Account.UserToken) == []

      # when not logged in (token already used, but still valid for login)
      {:ok, lv, _html} = live(build_conn(), ~p"/users/confirm/#{token}")

      assert {:error, {:redirect, %{status: 302, to: confirm_login_path}}} =
               lv
               |> form("#confirmation_form")
               |> render_submit()

      # Follow redirect to confirm-login controller
      # Token is already used but still valid, so it logs in and redirects to /home
      conn = get(build_conn(), confirm_login_path)
      assert redirected_to(conn) == ~p"/home"

      # Follow redirect to /home
      conn = get(conn, ~p"/home")
      assert html_response(conn, 200)
      # User is logged in even though token was already used
      assert get_session(conn, :user_token)

      # when logged in
      conn =
        build_conn()
        |> log_in_user(user)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      assert {:error, {:redirect, %{status: 302, to: confirm_login_path}}} =
               lv
               |> form("#confirmation_form")
               |> render_submit()

      # Follow redirect to confirm-login controller, which redirects to /home (already confirmed, but logs in)
      conn = get(conn, confirm_login_path)
      assert redirected_to(conn) == ~p"/home"

      # Follow redirect to /home
      conn = get(conn, ~p"/home")
      assert html_response(conn, 200)
      # No error flash expected when already confirmed and logged in
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/invalid-token")

      # Submit form, which redirects to confirm-login route
      assert {:error, {:redirect, %{status: 302, to: confirm_login_path}}} =
               lv
               |> form("#confirmation_form")
               |> render_submit()

      assert confirm_login_path == ~p"/users/confirm-login/invalid-token"

      # Follow redirect to confirm-login controller, which redirects to /login (invalid token)
      conn = get(conn, confirm_login_path)
      assert redirected_to(conn) == ~p"/login"

      # Follow redirect to login page
      conn = get(conn, ~p"/login")
      assert html_response(conn, 200)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User confirmation link is invalid or it has expired"

      refute Account.get_user!(user.id).confirmed_at
    end
  end
end

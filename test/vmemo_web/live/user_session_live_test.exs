defmodule VmemoWeb.UserSessionLiveTest do
  use VmemoWeb.ConnCase, async: true

  alias Vmemo.Account

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  describe "Login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Login"
      assert html =~ "Register"
      assert html =~ "Forgot your password?"
    end

    test "shows warning if already logged in", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/login")

      assert html =~ "You are currently logged in"
      assert html =~ user.email
      assert html =~ "Logout and Register"
    end
  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      user = user_fixture(%{password: password})
      {:ok, user} = Account.update_user(user, %{confirmed_at: DateTime.utc_now()})

      {:ok, lv, _html} = live(conn, ~p"/login")

      form =
        form(lv, "#login_form", user: %{email: user.email, password: password, remember_me: true})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/home"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: _conn
    } do
      # TODO: to be written later
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: _conn} do
      # TODO: to be written later
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/login")

      {:ok, conn} =
        lv
        |> element("main a", "Forgot your password?")
        |> render_click()
        |> follow_redirect(conn, ~p"/reset-password")

      assert conn.resp_body =~ "Forgot your password?"
    end
  end
end

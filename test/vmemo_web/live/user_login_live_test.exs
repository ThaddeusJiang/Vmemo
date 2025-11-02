defmodule VmemoWeb.UserLoginLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  describe "Sign in page" do
    test "renders sign in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/signin")

      assert html =~ "Sign in"
      assert html =~ "Sign up"
      assert html =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/signin")
        |> follow_redirect(conn, "/home")

      assert {:ok, _conn} = result
    end
  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      user = user_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, ~p"/signin")

      form =
        form(lv, "#login_form", user: %{email: user.email, password: password, remember_me: true})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/home"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      # TODO: 今后编写
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      # TODO: 今后编写
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/signin")

      {:ok, conn} =
        lv
        |> element("main a", "Forgot your password?")
        |> render_click()
        |> follow_redirect(conn, ~p"/reset-password")

      assert conn.resp_body =~ "Forgot your password?"
    end
  end
end

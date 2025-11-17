defmodule VmemoWeb.UserRegistrationLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: _conn} do
      # TODO: 今后编写
    end

    test "shows warning if already logged in", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/register")

      assert html =~ "You are currently logged in"
      assert html =~ user.email
      assert html =~ "Sign Out and Register"
    end

    test "renders errors for invalid data", %{conn: _conn} do
      # TODO: 今后编写
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: _conn} do
      # TODO: 今后编写
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          form: %{"email" => user.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Login button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Login")
        |> render_click()
        |> follow_redirect(conn, ~p"/login")

      assert login_html =~ "Login"
    end
  end
end

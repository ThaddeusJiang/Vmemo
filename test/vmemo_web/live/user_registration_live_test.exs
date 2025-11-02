defmodule VmemoWeb.UserRegistrationLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      # TODO: 今后编写
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/signup")
        |> follow_redirect(conn, "/home")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      # TODO: 今后编写
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      # TODO: 今后编写
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Sign in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign in")
        |> render_click()
        |> follow_redirect(conn, ~p"/signin")

      assert login_html =~ "Sign in"
    end
  end
end

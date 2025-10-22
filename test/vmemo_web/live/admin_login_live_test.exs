defmodule VmemoWeb.AdminLoginLiveTest do
  use VmemoWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "AdminLoginLive" do
    test "renders login form", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/login")

      assert html =~ "Admin Login"
      assert html =~ "Please enter your admin token to access the admin panel"
      assert has_element?(view, "form#admin-login-form")
      assert has_element?(view, "input[name=\"admin[token]\"]")
    end

    test "redirects to admin when already logged in", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = put_session(conn, "admin_token", "admin")

      assert {:error, {:redirect, %{to: "/admin"}}} = live(conn, ~p"/admin/login")
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/login")

      view
      |> element("form#admin-login-form")
      |> render_change(%{"admin" => %{"token" => "test"}})

      # Form should still be valid
      assert has_element?(view, "form#admin-login-form")
    end

    test "displays error message from flash", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = fetch_flash(conn)
      conn = put_flash(conn, :error, "Invalid admin token")

      {:ok, _view, html} = live(conn, ~p"/admin/login")

      assert html =~ "Invalid admin token"
      assert html =~ "text-red-600"
    end

    test "does not display error message when none present", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/login")

      refute html =~ "Invalid admin token"
      refute html =~ "Please provide admin token"
    end
  end
end

defmodule VmemoWeb.AdminLoginLiveTest do
  use VmemoWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "AdminLoginLive" do
    test "renders login form", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/login")

      assert html =~ "管理员登录"
      assert html =~ "请输入管理员 token"
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
      |> element("input[name=\"admin[token]\"]")
      |> render_change(%{"admin" => %{"token" => "test"}})

      # Form should still be valid
      assert has_element?(view, "form#admin-login-form")
    end
  end
end

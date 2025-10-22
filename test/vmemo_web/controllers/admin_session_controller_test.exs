defmodule VmemoWeb.AdminSessionControllerTest do
  use VmemoWeb.ConnCase, async: true

  import VmemoWeb.AdminAuth

  describe "POST /admin/login" do
    test "logs in admin with correct token", %{conn: conn} do
      conn = post(conn, ~p"/admin/login", %{"admin" => %{"token" => "admin"}})

      assert redirected_to(conn) == "/admin"
      assert get_flash(conn, :info) == "管理员登录成功"
      assert admin_logged_in?(conn)
    end

    test "rejects login with incorrect token", %{conn: conn} do
      conn = post(conn, ~p"/admin/login", %{"admin" => %{"token" => "wrong_token"}})

      assert redirected_to(conn) == "/admin/login"
      assert get_flash(conn, :error) == "无效的管理员 token"
      refute admin_logged_in?(conn)
    end

    test "rejects login without token", %{conn: conn} do
      conn = post(conn, ~p"/admin/login", %{"admin" => %{}})

      assert redirected_to(conn) == "/admin/login"
      assert get_flash(conn, :error) == "请提供管理员 token"
    end
  end

  describe "DELETE /admin/logout" do
    test "logs out admin", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = put_session(conn, "admin_token", "admin")
      conn = delete(conn, ~p"/admin/logout")

      assert redirected_to(conn) == "/admin/login"
      refute admin_logged_in?(conn)
    end
  end
end

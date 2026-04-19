defmodule VmemoWeb.AdminAuthTest do
  use VmemoWeb.ConnCase, async: true

  alias VmemoWeb.AdminAuth

  describe "admin_logged_in?/1" do
    test "returns true when admin is logged in", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = put_session(conn, "admin_token", "admin")
      assert AdminAuth.admin_logged_in?(conn)
    end

    test "returns false when admin is not logged in", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      refute AdminAuth.admin_logged_in?(conn)
    end
  end

  describe "verify_admin_token/1" do
    test "returns true for correct token" do
      assert AdminAuth.verify_admin_token("admin")
    end

    test "returns false for incorrect token" do
      refute AdminAuth.verify_admin_token("wrong_token")
    end

    test "returns false for nil token" do
      refute AdminAuth.verify_admin_token(nil)
    end
  end

  describe "require_admin/2" do
    test "allows access when admin is logged in", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = put_session(conn, "admin_token", "admin")
      conn = AdminAuth.require_admin(conn, [])

      refute conn.halted
    end

    test "redirects to login when admin is not logged in", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = fetch_flash(conn)
      conn = AdminAuth.require_admin(conn, [])

      assert conn.halted
      assert redirected_to(conn) == "/admin/login"
    end

    test "redirects silently when silent option is true", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = fetch_flash(conn)
      conn = AdminAuth.require_admin(conn, silent: true)

      assert conn.halted
      assert redirected_to(conn) == "/admin/login"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end
  end

  describe "require_admin_silent/2" do
    test "allows access when admin is logged in", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = put_session(conn, "admin_token", "admin")
      conn = AdminAuth.require_admin_silent(conn, [])

      refute conn.halted
    end

    test "redirects silently when admin is not logged in", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      conn = fetch_flash(conn)
      conn = AdminAuth.require_admin_silent(conn, [])

      assert conn.halted
      assert redirected_to(conn) == "/admin/login"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end
  end
end

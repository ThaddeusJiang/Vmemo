defmodule VmemoWeb.TokenLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures
  import VmemoWeb.ApiFixtures

  describe "Index - 显示 Token 列表" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, conn: conn, user: user}
    end

    test "显示空的 Token 列表", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "API Token Management"
      assert html =~ "Total Tokens"
      assert html =~ "0"
    end

    test "显示 Token 统计数据", %{conn: conn, user: user} do
      # 创建一个测试 token
      create_test_token(user)

      {:ok, _index_live, html} = live(conn, ~p"/tokens")

      assert html =~ "Total Tokens"
      assert html =~ "Active Tokens"
      assert html =~ "Expired Tokens"
    end

    test "可以导航到创建页面", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/tokens")

      assert has_element?(index_live, "a[href='#{~p"/tokens/new"}']")
    end
  end

  describe "Form - 创建 Token" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, conn: conn, user: user}
    end

    test "显示创建表单", %{conn: conn} do
      {:ok, _form_live, html} = live(conn, ~p"/tokens/new")

      assert html =~ "Create API Token"
      assert html =~ "Token Name"
      assert html =~ "Expiration"
    end
  end
end

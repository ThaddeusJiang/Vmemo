defmodule VmemoWeb.UserProfileControllerTest do
  use VmemoWeb.ConnCase, async: true

  alias Vmemo.Account

  import Vmemo.AccountFixtures

  describe "POST /profile/appearance" do
    test "updates appearance and creates profile", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> put_req_header("referer", "/profile")
        |> post(~p"/profile/appearance", %{"appearance" => "dark"})

      assert redirected_to(conn) == ~p"/profile"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Appearance updated."

      profile = Account.get_user_profile_by_user_id(user.id)
      assert profile.appearance == "dark"
      assert profile.language == "en"
    end

    test "rejects invalid appearance value", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/profile/appearance", %{"appearance" => "invalid"})

      assert redirected_to(conn) == ~p"/home"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid appearance value."

      assert Account.get_user_profile_by_user_id(user.id) == nil
    end
  end

  describe "root layout theme and language" do
    test "applies user language and theme attributes", %{conn: conn} do
      user = user_fixture()

      {:ok, _profile} =
        Account.upsert_user_profile(user, %{name: "Alice", language: "zh", appearance: "dark"})

      response =
        conn
        |> log_in_user(user)
        |> get(~p"/home")
        |> html_response(200)

      assert response =~ ~s(lang="zh-CN")
      assert response =~ ~s(data-theme="dark")
    end
  end
end

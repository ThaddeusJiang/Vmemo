defmodule VmemoWeb.UserProfileLiveTest do
  use VmemoWeb.ConnCase, async: true

  alias Vmemo.Account
  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  describe "Profile page" do
    test "renders profile page", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/profile")

      assert html =~ "User Profile"
      assert html =~ "Language"
      refute html =~ "Save Profile"

      changed_html =
        lv
        |> form("form[phx-submit=save]", %{
          "profile" => %{
            "name" => "Alice"
          }
        })
        |> render_change()

      assert changed_html =~ "Save Profile"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/profile")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/login"
      assert %{"error" => "You must login to access this page."} = flash
    end

    test "updates name and language", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/profile")

      result =
        lv
        |> form("form[phx-submit=save]", %{
          "profile" => %{
            "name" => "Alice",
            "language" => "ja"
          }
        })
        |> render_submit()

      assert {:error, {:redirect, %{to: "/profile", flash: flash_token}}} = result
      assert flash_token

      profile = Account.get_user_profile_by_user_id(user.id)
      assert profile.name == "Alice"
      assert profile.language == "ja"
      assert profile.appearance == "system"
    end
  end
end

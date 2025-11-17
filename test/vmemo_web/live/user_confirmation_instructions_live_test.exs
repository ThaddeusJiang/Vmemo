defmodule VmemoWeb.UserConfirmationInstructionsLiveTest do
  use VmemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      # Token verification removed - Ash uses JWT tokens instead of UserToken records
      # assert Repo.get_by!(Account.UserToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if user is confirmed", %{conn: _conn, user: _user} do
      # TODO: 今后编写
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", user: %{email: "unknown@vmemo.app"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      # Token verification removed - Ash uses JWT tokens instead of UserToken records
      # assert Repo.all(Account.UserToken) == []
    end
  end
end

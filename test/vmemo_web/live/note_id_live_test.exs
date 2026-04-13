defmodule VmemoWeb.NoteIdLiveTest do
  use VmemoWeb.ConnCase, async: true

  alias Ash
  alias Vmemo.Memo.Note
  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  describe "note update form" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, note} =
        Ash.create(
          Note,
          %{text: "Original note", user_id: user.id},
          action: :import,
          actor: user
        )

      %{conn: conn, user: user, note: note}
    end

    test "updates note text from nested form params", %{conn: conn, note: note, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/notes/#{note.id}")

      refute has_element?(lv, "button", "Save")

      lv
      |> element("form")
      |> render_change(%{"note" => %{"note" => "Updated note text"}})

      assert has_element?(lv, "button", "Save")

      lv
      |> element("form")
      |> render_submit(%{"note" => %{"note" => "Updated note text"}})

      {:ok, updated_note} = Ash.get(Note, note.id, actor: user)
      assert updated_note.text == "Updated note text"
    end
  end
end

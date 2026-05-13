defmodule VmemoWeb.TagsLiveTest do
  use VmemoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  alias Vmemo.Memo.Changes.SyncImageTags
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.Tag

  describe "tags pages" do
    setup %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      conn = log_in_user(conn, user)

      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/tag-owner.jpg",
          note: "",
          caption: "",
          file_id: "tag-owner.jpg",
          user_id: user.id
        })

      other_image =
        create_image!(%{
          url: "/storage/v1/#{other_user.id}/images/tag-other.jpg",
          note: "",
          caption: "",
          file_id: "tag-other.jpg",
          user_id: other_user.id
        })

      :ok = SyncImageTags.sync_for_image(image, ["English Grammar", "Selfie"])
      :ok = SyncImageTags.sync_for_image(other_image, ["English Grammar"])

      english_tag =
        Tag
        |> Ash.read!(actor: nil, authorize?: false)
        |> Enum.find(&(&1.name == "English Grammar"))

      %{conn: conn, user: user, english_tag: english_tag}
    end

    test "index shows only current user tags and usage counts", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/tags")

      assert html =~ "Tags"
      assert html =~ "#English Grammar"
      assert html =~ "#Selfie"
      assert html =~ "2"
      refute html =~ "No tags yet"
    end

    test "show page renders tag images for current user only", %{
      conn: conn,
      english_tag: english_tag
    } do
      {:ok, _lv, html} = live(conn, ~p"/tags/#{english_tag.id}")

      assert html =~ "#English Grammar"
      assert html =~ "images"
      assert html =~ "/images/"
      assert html =~ "/storage/v1/"
      assert html =~ "tag-owner.jpg"
      refute html =~ "tag-other.jpg"
    end

    test "show page renders not found for unknown tag id", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/tags/#{Ecto.UUID.generate()}")
      assert html =~ "Page not found"
    end
  end

  defp create_image!(attrs) do
    {:ok, image} = Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false)
    image
  end
end

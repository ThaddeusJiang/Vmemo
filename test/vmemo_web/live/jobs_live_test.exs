defmodule VmemoWeb.JobsLiveTest do
  use VmemoWeb.ConnCase, async: true

  alias Ash
  alias Vmemo.Memo.Image
  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  describe "jobs page" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/failed-caption.jpg",
        note: "failed",
        caption: "failed",
        file_id: "failed-caption.jpg",
        user_id: user.id,
        typesense_status: "processing",
        moondream_status: "failed"
      })

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/in-progress.jpg",
        note: "processing",
        caption: "processing",
        file_id: "in-progress.jpg",
        user_id: user.id,
        typesense_status: "processing",
        moondream_status: "processing"
      })

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/completed.jpg",
        note: "completed",
        caption: "completed",
        file_id: "completed.jpg",
        user_id: user.id,
        typesense_status: "completed",
        moondream_status: "completed"
      })

      %{conn: conn}
    end

    test "renders readable failure mapping", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/jobs")

      assert html =~ "Jobs"
      assert html =~ "Search embedding"
      assert html =~ "Vision embedding"
      assert html =~ "Timeout"
      assert html =~ "/storage/v1/"
      assert html =~ "Retry"
    end

    test "shows jobs summary near avatar", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/home")

      assert html =~ "Processing 1 / Failed 1"
      assert html =~ "href=\"/jobs\""
    end
  end

  defp create_image!(attrs) do
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, image} -> image
      {:error, error} -> raise "failed to create image: #{inspect(error)}"
    end
  end
end

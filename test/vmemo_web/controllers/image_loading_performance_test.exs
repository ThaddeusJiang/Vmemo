defmodule VmemoWeb.ImageLoadingPerformanceTest do
  use VmemoWeb.ConnCase, async: false

  import Vmemo.AccountFixtures

  alias Vmemo.Memo.ImageStorage
  alias Vmemo.Memo.Image

  @base_dir Path.join(["storage", "v1"])
  @moduletag :integration
  @threshold_ms 1_000

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    image_dir = Path.join([@base_dir, user.id, "images"])
    File.mkdir_p!(image_dir)

    on_exit(fn ->
      File.rm_rf!(Path.join([@base_dir, user.id]))
    end)

    {:ok, conn: conn, user: user, image_dir: image_dir}
  end

  test "warm thumb and detail image variants respond within one second", %{
    conn: conn,
    user: user,
    image_dir: image_dir
  } do
    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "performance.png")
    File.cp!(fixture, original)
    ImageStorage.thumbs!(original)

    image =
      Ash.create!(
        Image,
        %{
          url: "/storage/v1/#{user.id}/images/performance.png",
          note: "performance",
          caption: "performance",
          file_id: "performance.png",
          user_id: user.id
        },
        action: :import,
        actor: nil,
        authorize?: false
      )

    thumb_path = ~p"/media/images/#{image.id}/thumb"
    detail_path = ~p"/media/images/#{image.id}/detail"

    assert_request_under(conn, thumb_path, @threshold_ms)
    assert_request_under(conn, detail_path, @threshold_ms)
  end

  defp assert_request_under(conn, path, threshold_ms) do
    {microseconds, conn} = :timer.tc(fn -> get(conn, path) end)

    assert response(conn, 200) != ""
    assert microseconds < System.convert_time_unit(threshold_ms, :millisecond, :microsecond)
  end
end

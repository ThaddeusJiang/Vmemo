defmodule VmemoWeb.JobsLiveTest do
  use VmemoWeb.ConnCase, async: true
  require Ash.Query

  alias Ash
  alias Vmemo.Memo.Image
  alias Vmemo.Jobs.Job
  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures
  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

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

      %{conn: conn, user: user}
    end

    test "renders readable failure mapping", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/jobs")

      assert html =~ "Jobs"
      assert html =~ "Search embedding"
      assert html =~ "Vision embedding"
      assert html =~ "Caption generation failed."
      refute html =~ "Timeout"
      assert html =~ "/storage/v1/"
      assert html =~ "Retry"
    end

    test "shows notifications entry near avatar", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/home")

      assert html =~ "Notifications"
      refute html =~ "Processing 1 / Failed 1"
      refute Regex.match?(~r/<a[^>]*href="\/jobs"[^>]*btn btn-ghost btn-circle/, html)
    end

    test "renders notification items as links to job detail page", %{
      conn: conn,
      user: user
    } do
      batch_id = Ecto.UUID.generate()

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/batch-live-1.jpg",
        note: "batch-live-1",
        caption: "batch-live-1",
        file_id: "batch-live-1.jpg",
        user_id: user.id,
        upload_batch_id: batch_id,
        typesense_status: "processing",
        moondream_status: "processing"
      })

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/batch-live-2.jpg",
        note: "batch-live-2",
        caption: "batch-live-2",
        file_id: "batch-live-2.jpg",
        user_id: user.id,
        upload_batch_id: batch_id,
        typesense_status: "processing",
        moondream_status: "processing"
      })

      {:ok, _lv, html} = live(conn, ~p"/home")

      assert Regex.match?(~r/href="\/jobs\/[^"]+"/, html)
      assert html =~ "notification-item-thumb"
    end

    test "renders caption failure reason in job detail page", %{conn: conn, user: user} do
      failed_image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/detail-failed.jpg",
          note: "detail-failed",
          caption: "detail-failed",
          file_id: "detail-failed.jpg",
          user_id: user.id,
          typesense_status: "completed",
          moondream_status: "failed"
        })

      {:ok, _lv, html} = live(conn, ~p"/jobs/#{failed_image.id}")

      assert html =~ "Jobs"
      assert html =~ failed_image.id
      assert html =~ "Failure reason"
      assert html =~ "Caption generation failed."
      refute html =~ "Timeout"
      assert html =~ "Retry Vision AI caption"
      assert html =~ ~s(href="/images/#{failed_image.id}")
    end

    test "renders caption text when caption succeeds in job detail page", %{
      conn: conn,
      user: user
    } do
      completed_image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/detail-success.jpg",
          note: "detail-success",
          caption: "detail-success-caption",
          file_id: "detail-success.jpg",
          user_id: user.id,
          typesense_status: "completed",
          moondream_status: "completed"
        })

      {:ok, _lv, html} = live(conn, ~p"/jobs/#{completed_image.id}")

      assert html =~ "Caption result"
      assert html =~ "detail-success-caption"
      assert html =~ ~s(href="/jobs")
    end
  end

  defp create_image!(attrs) do
    ensure_fixture_image!(attrs)

    {typesense_status, attrs} = Map.pop(attrs, :typesense_status, "completed")
    {moondream_status, attrs} = Map.pop(attrs, :moondream_status, "completed")
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, image} ->
        {:ok, image} =
          Ash.update(
            image,
            %{typesense_status: typesense_status},
            action: :set_typesense_status,
            actor: nil,
            authorize?: false
          )

        {:ok, image} =
          Ash.update(
            image,
            %{moondream_status: moondream_status},
            action: :set_moondream_status,
            actor: nil,
            authorize?: false
          )

        maybe_insert_default_jobs!(image, typesense_status, moondream_status)
        image

      {:error, error} ->
        raise "failed to create image: #{inspect(error)}"
    end
  end

  defp ensure_fixture_image!(attrs) do
    user_id = Map.fetch!(attrs, :user_id)
    file_id = Map.fetch!(attrs, :file_id)
    image_dir = Path.join(["storage", "v1", user_id, "images"])
    image_path = Path.join(image_dir, file_id)

    File.mkdir_p!(image_dir)

    unless File.exists?(image_path) do
      File.cp!(@fixture_image, image_path)
    end
  end

  defp maybe_insert_default_jobs!(image, typesense_status, moondream_status) do
    insert_async_job!(
      image.id,
      image.user_id,
      "typesense",
      job_status_from_status(typesense_status)
    )

    insert_async_job!(
      image.id,
      image.user_id,
      "caption",
      job_status_from_status(moondream_status)
    )
  end

  defp insert_async_job!(image_id, user_id, kind, status) do
    query =
      Job
      |> Ash.Query.filter(image_id: image_id, kind: kind)
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: nil, authorize?: false) do
      {:ok, [existing | _]} ->
        {:ok, _job} =
          Ash.update(
            existing,
            %{},
            action: map_update_action(status),
            actor: nil,
            authorize?: false
          )

      _ ->
        {:ok, _job} =
          Ash.create(
            Job,
            %{
              image_id: image_id,
              user_id: user_id,
              kind: kind,
              status: status
            },
            action: :create_requested,
            actor: nil,
            authorize?: false
          )
    end
  end

  defp job_status_from_status("completed"), do: "completed"
  defp job_status_from_status("failed"), do: "failed"
  defp job_status_from_status("processing"), do: "in_progress"
  defp job_status_from_status("pending"), do: "requested"
  defp job_status_from_status(_), do: "requested"

  defp map_update_action("requested"), do: :mark_requested
  defp map_update_action("in_progress"), do: :mark_in_progress
  defp map_update_action("completed"), do: :mark_completed
  defp map_update_action("failed"), do: :mark_failed
  defp map_update_action("discarded"), do: :mark_discarded
  defp map_update_action("cancelled"), do: :mark_cancelled
  defp map_update_action(_), do: :mark_failed
end

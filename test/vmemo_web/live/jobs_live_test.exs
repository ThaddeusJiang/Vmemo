defmodule VmemoWeb.JobsLiveTest do
  use VmemoWeb.ConnCase, async: true

  alias Ash
  alias Oban.Job
  alias Vmemo.Memo.Image
  alias Vmemo.Repo
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
    insert_oban_job!(
      image.id,
      "Vmemo.Memo.Image.Workers.SyncTypesense",
      oban_state_from_status(typesense_status),
      "sync_typesense"
    )

    insert_oban_job!(
      image.id,
      "Vmemo.Memo.Image.Workers.GenerateCaption",
      oban_state_from_status(moondream_status),
      "ai_vision"
    )
  end

  defp insert_oban_job!(image_id, worker, state, queue) do
    args = %{"primary_key" => %{"id" => image_id}}

    changeset =
      Job.new(args,
        worker: worker,
        queue: queue
      )
      |> Ecto.Changeset.put_change(:state, state)

    Repo.insert!(changeset)
  end

  defp oban_state_from_status("completed"), do: "completed"
  defp oban_state_from_status("failed"), do: "discarded"
  defp oban_state_from_status("processing"), do: "executing"
  defp oban_state_from_status("pending"), do: "available"
  defp oban_state_from_status(_), do: "available"
end

defmodule Vmemo.Memo.ImageJobsTest do
  use Vmemo.DataCase, async: true
  require Ash.Query

  alias Ash
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageJobs
  alias Vmemo.Jobs.Job

  import Vmemo.AccountFixtures

  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

  describe "list_notifications/2" do
    test "uses async job resource states as source of truth for success" do
      user = user_fixture()

      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/oban-source-of-truth.jpg",
          note: "oban-source-of-truth",
          caption: "caption-from-ai",
          file_id: "oban-source-of-truth.jpg",
          user_id: user.id,
          typesense_status: "processing",
          moondream_status: "processing"
        })

      insert_async_job!(
        image.id,
        user.id,
        "caption",
        "completed"
      )

      insert_async_job!(
        image.id,
        user.id,
        "typesense",
        "completed"
      )

      {:ok, notifications} = ImageJobs.list_notifications(user, limit: 20)

      [notification] = Enum.filter(notifications, &(&1.image_id == image.id))
      assert notification.status == "success"
      assert notification.description == "caption-from-ai"
    end

    test "does not return rows when no related async job exists" do
      user = user_fixture()

      image =
        create_image!(
          %{
            url: "/storage/v1/#{user.id}/images/no-job.jpg",
            note: "no-job",
            caption: "no-job",
            file_id: "no-job.jpg",
            user_id: user.id,
            typesense_status: "completed",
            moondream_status: "completed"
          },
          insert_default_jobs?: false,
          update_statuses?: false
        )

      {:ok, notifications} = ImageJobs.list_notifications(user, limit: 20)
      refute Enum.any?(notifications, &(&1.image_id == image.id))
    end
  end

  defp create_image!(attrs, opts \\ []) do
    ensure_fixture_image!(attrs)

    {typesense_status, attrs} = Map.pop(attrs, :typesense_status, "completed")
    {moondream_status, attrs} = Map.pop(attrs, :moondream_status, "completed")
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, image} ->
        image =
          if Keyword.get(opts, :update_statuses?, true) do
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

            image
          else
            image
          end

        if Keyword.get(opts, :insert_default_jobs?, true) do
          maybe_insert_default_jobs!(image, typesense_status, moondream_status)
        end

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

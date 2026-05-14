defmodule Vmemo.Memo.ImageJobsTest do
  use Vmemo.DataCase, async: true

  alias Ash
  alias Oban.Job
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageJobs
  alias Vmemo.Repo

  import Vmemo.AccountFixtures

  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

  describe "list_notifications/2" do
    test "uses oban worker states as source of truth for success" do
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

      insert_oban_job!(
        image.id,
        "Vmemo.Memo.Image.Workers.GenerateCaption",
        "completed",
        "ai_vision"
      )

      insert_oban_job!(
        image.id,
        "Vmemo.Memo.Image.Workers.SyncTypesense",
        "completed",
        "sync_typesense"
      )

      {:ok, notifications} = ImageJobs.list_notifications(user, limit: 20)

      [notification] = Enum.filter(notifications, &(&1.image_id == image.id))
      assert notification.status == "success"
      assert notification.description == "caption-from-ai"
    end

    test "does not return rows when no related oban job exists" do
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
          insert_default_jobs?: false
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

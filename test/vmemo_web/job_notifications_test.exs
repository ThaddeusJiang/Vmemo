defmodule VmemoWeb.JobNotificationsTest do
  use Vmemo.DataCase, async: true
  require Ash.Query

  alias Ash
  alias Vmemo.Jobs.Job
  alias Vmemo.Memo.Image
  alias VmemoWeb.JobNotifications

  import Vmemo.AccountFixtures

  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

  test "builds caption and typesense messages by job status" do
    user = user_fixture()

    image =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/notify-message.jpg",
        note: "notify-message",
        caption: "caption-from-ai",
        file_id: "notify-message.jpg",
        user_id: user.id
      })

    failed_caption = insert_job!(image.id, user.id, "caption", "failed", nil)
    _processing_typesense = insert_job!(image.id, user.id, "typesense", "in_progress", nil)

    {:ok, notifications} = JobNotifications.list_for_user(user, limit: 20)

    caption_notification = Enum.find(notifications, &(&1.id == failed_caption.id))
    assert caption_notification.description == "Caption generation failed."
    assert caption_notification.status == "failed"

    completed_caption =
      Ash.update!(failed_caption, %{}, action: :mark_completed, actor: nil, authorize?: false)

    {:ok, notifications2} = JobNotifications.list_for_user(user, limit: 20)
    completed_caption_notification = Enum.find(notifications2, &(&1.id == completed_caption.id))
    assert completed_caption_notification.description == "caption-from-ai"
    assert completed_caption_notification.status == "success"

    assert Enum.any?(notifications2, &(&1.description == "Search indexing in progress."))
  end

  defp create_image!(attrs) do
    ensure_fixture_image!(attrs)
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, image} -> image
      {:error, error} -> raise "failed to create image: #{inspect(error)}"
    end
  end

  defp insert_job!(image_id, user_id, kind, status, error) do
    {:ok, job} =
      Ash.create(
        Job,
        %{image_id: image_id, user_id: user_id, kind: kind, status: status, error: error},
        action: :create_requested,
        actor: nil,
        authorize?: false
      )

    update_action =
      case status do
        "requested" -> :mark_requested
        "in_progress" -> :mark_in_progress
        "completed" -> :mark_completed
        "failed" -> :mark_failed
        "cancelled" -> :mark_cancelled
        "discarded" -> :mark_discarded
        _ -> :mark_requested
      end

    attrs = if status in ["failed", "cancelled", "discarded"], do: %{error: error}, else: %{}

    Ash.update!(job, attrs, action: update_action, actor: nil, authorize?: false)
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
end

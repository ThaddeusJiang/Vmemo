defmodule VmemoWeb.JobNotificationsTest do
  use Vmemo.DataCase, async: true
  require Ash.Query

  alias Ash
  alias Vmemo.Jobs.Job
  alias Vmemo.Memo.Image
  alias Vmemo.Storage
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
    assert caption_notification.description == "Caption generation failed. Please retry later."

    assert caption_notification.image_url == "/media/images/#{image.id}/thumb"

    assert caption_notification.status == "failed"

    completed_caption =
      Ash.update!(failed_caption, %{}, action: :mark_completed, actor: nil, authorize?: false)

    {:ok, notifications2} = JobNotifications.list_for_user(user, limit: 20)
    completed_caption_notification = Enum.find(notifications2, &(&1.id == completed_caption.id))
    assert completed_caption_notification.description == "caption-from-ai"
    assert completed_caption_notification.status == "success"

    assert Enum.any?(notifications2, &(&1.description == "Search indexing in progress."))
  end

  test "hides internal job error details in notification messages" do
    user = user_fixture()

    image =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/notify-internal-error.jpg",
        note: "notify-internal-error",
        caption: "notify-internal-error",
        file_id: "notify-internal-error.jpg",
        user_id: user.id
      })

    internal_error =
      "%Ash.Error.Unknown{errors: [%ReqLLM.Error.API.Request{reason: \"Provider response error (401): Openrouter API error: User not found.\", status: 401}]}"

    failed_caption = insert_job!(image.id, user.id, "caption", "failed", internal_error)

    {:ok, notifications} = JobNotifications.list_for_user(user, limit: 20)
    notification = Enum.find(notifications, &(&1.id == failed_caption.id))

    assert notification.description == "Caption generation failed. Please retry later."
    refute notification.description =~ "%Ash.Error"
    refute notification.description =~ "Provider response error"
  end

  test "deleting an image removes related jobs and notifications" do
    user = user_fixture()

    image =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/notify-delete.jpg",
        note: "notify-delete",
        caption: "notify-delete",
        file_id: "notify-delete.jpg",
        user_id: user.id
      })

    caption_job = insert_job!(image.id, user.id, "caption", "failed", "caption failed")
    typesense_job = insert_job!(image.id, user.id, "typesense", "in_progress", nil)

    {:ok, notifications} = JobNotifications.list_for_user(user, limit: 20)
    assert Enum.any?(notifications, &(&1.id == caption_job.id))
    assert Enum.any?(notifications, &(&1.id == typesense_job.id))

    Ash.destroy!(image, action: :destroy, actor: nil, authorize?: false)

    remaining_jobs =
      Job
      |> Ash.Query.filter(image_id == ^image.id)
      |> Ash.read!(actor: nil, authorize?: false)

    assert remaining_jobs == []

    {:ok, remaining_notifications} = JobNotifications.list_for_user(user, limit: 20)
    refute Enum.any?(remaining_notifications, &(&1.id in [caption_job.id, typesense_job.id]))
  end

  test "deleting an image broadcasts a user notification refresh" do
    user = user_fixture()

    image =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/notify-delete-broadcast.jpg",
        note: "notify-delete-broadcast",
        caption: "notify-delete-broadcast",
        file_id: "notify-delete-broadcast.jpg",
        user_id: user.id
      })

    _caption_job = insert_job!(image.id, user.id, "caption", "failed", "caption failed")

    Phoenix.PubSub.subscribe(Vmemo.PubSub, "user_notification:#{user.id}")

    Ash.destroy!(image, action: :destroy, actor: nil, authorize?: false)

    user_id = user.id
    image_id = image.id

    assert_receive {:user_notifications_changed,
                    %{user_id: ^user_id, image_id: ^image_id, reason: :image_deleted}}
  end

  test "updating a job broadcasts a user notification refresh" do
    user = user_fixture()

    image =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/notify-job-update.jpg",
        note: "notify-job-update",
        caption: "notify-job-update",
        file_id: "notify-job-update.jpg",
        user_id: user.id
      })

    job = insert_job!(image.id, user.id, "caption", "in_progress", nil)

    Phoenix.PubSub.subscribe(Vmemo.PubSub, "user_notification:#{user.id}")

    Ash.update!(job, %{}, action: :mark_completed, actor: nil, authorize?: false)

    user_id = user.id
    image_id = image.id
    job_id = job.id

    assert_receive {:user_notifications_changed,
                    %{
                      user_id: ^user_id,
                      image_id: ^image_id,
                      job_id: ^job_id,
                      reason: :job_changed
                    }}
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
    image_dir = Storage.path(["v1", user_id, "images"])
    image_path = Path.join(image_dir, file_id)

    File.mkdir_p!(image_dir)

    unless File.exists?(image_path) do
      File.cp!(@fixture_image, image_path)
    end
  end
end

defmodule VmemoWeb.ImageJobsHookTest do
  use Vmemo.DataCase, async: true

  alias Ash
  alias Vmemo.Memo.Image
  alias VmemoWeb.Live.ImageJobsHook

  import Vmemo.AccountFixtures

  describe "list_notifications/2" do
    test "aggregates multiple uploaded images into one notification by upload_batch_id" do
      user = user_fixture()
      batch_id = Ecto.UUID.generate()

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/batch-a-1.jpg",
        note: "batch-a-1",
        caption: "batch-a-1",
        file_id: "batch-a-1.jpg",
        user_id: user.id,
        upload_batch_id: batch_id,
        typesense_status: "failed",
        moondream_status: "processing"
      })

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/batch-a-2.jpg",
        note: "batch-a-2",
        caption: "batch-a-2",
        file_id: "batch-a-2.jpg",
        user_id: user.id,
        upload_batch_id: batch_id,
        typesense_status: "completed",
        moondream_status: "completed"
      })

      {:ok, notifications} = ImageJobsHook.list_notifications(user, limit: 20)

      assert length(notifications) == 1

      [notification] = notifications
      assert notification.upload_batch_id == batch_id
      assert notification.total_count == 2
      assert notification.failed_count == 1
      assert notification.success_count == 1
      assert notification.status == "partial_failed"
    end

    test "ignores images without upload_batch_id" do
      user = user_fixture()

      create_image!(%{
        url: "/storage/v1/#{user.id}/images/no-batch.jpg",
        note: "no-batch",
        caption: "no-batch",
        file_id: "no-batch.jpg",
        user_id: user.id,
        typesense_status: "processing",
        moondream_status: "processing"
      })

      {:ok, notifications} = ImageJobsHook.list_notifications(user, limit: 20)

      assert notifications == []
    end
  end

  defp create_image!(attrs) do
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

        image

      {:error, error} ->
        raise "failed to create image: #{inspect(error)}"
    end
  end
end

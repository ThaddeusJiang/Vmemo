defmodule VmemoWeb.ImageJobsHookTest do
  use Vmemo.DataCase, async: true

  alias Ash
  alias Vmemo.Memo.Image
  alias VmemoWeb.Live.ImageJobsHook

  import Vmemo.AccountFixtures

  describe "list_notifications/2" do
    test "maps uploaded images to one notification per job" do
      user = user_fixture()
      batch_id = Ecto.UUID.generate()

      image_a =
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

      image_b =
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

      assert length(notifications) == 2

      notification_by_id = Map.new(notifications, &{&1.image_id, &1})

      assert Map.keys(notification_by_id) |> Enum.sort() ==
               [image_a.id, image_b.id] |> Enum.sort()

      failed = notification_by_id[image_a.id]
      assert failed.status == "failed"
      assert failed.description =~ "Indexing error"

      success = notification_by_id[image_b.id]
      assert success.status == "success"
      assert success.description == "batch-a-2"
    end

    test "includes images without upload_batch_id as independent notifications" do
      user = user_fixture()

      image =
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

      assert length(notifications) == 1
      [notification] = notifications
      assert notification.image_id == image.id
      assert notification.status == "processing"
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

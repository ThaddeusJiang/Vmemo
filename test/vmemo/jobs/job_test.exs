defmodule Vmemo.Jobs.JobTest do
  use Vmemo.DataCase, async: true

  alias Ash
  alias Vmemo.Memo.Image
  alias Vmemo.Jobs.Job

  import Vmemo.AccountFixtures

  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

  describe "retry action" do
    test "retries caption job through image request action" do
      user = user_fixture()

      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/retry-caption.jpg",
          note: "retry-caption",
          caption: "retry-caption",
          file_id: "retry-caption.jpg",
          user_id: user.id
        })

      {:ok, job} =
        Ash.create(
          Job,
          %{image_id: image.id, user_id: user.id, kind: "caption", status: "failed", error: "x"},
          action: :create_requested,
          actor: nil,
          authorize?: false
        )

      {:ok, retried} = Ash.update(job, %{}, action: :retry, actor: nil, authorize?: false)

      assert retried.status == "requested"
      assert retried.error == nil

      {:ok, refreshed_image} = Image.get(image.id, actor: nil, authorize?: false)
      refute refreshed_image.moondream_status == "failed"
    end

    test "retries typesense job through image search update action" do
      user = user_fixture()

      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/retry-typesense.jpg",
          note: "retry-typesense",
          caption: "retry-typesense",
          file_id: "retry-typesense.jpg",
          user_id: user.id
        })

      {:ok, job} =
        Ash.create(
          Job,
          %{
            image_id: image.id,
            user_id: user.id,
            kind: "typesense",
            status: "failed",
            error: "x"
          },
          action: :create_requested,
          actor: nil,
          authorize?: false
        )

      {:ok, retried} = Ash.update(job, %{}, action: :retry, actor: nil, authorize?: false)

      assert retried.status == "requested"
      assert retried.error == nil

      {:ok, refreshed_image} = Image.get(image.id, actor: nil, authorize?: false)
      refute refreshed_image.typesense_status == "failed"
    end
  end

  defp create_image!(attrs) do
    ensure_fixture_image!(attrs)
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, image} -> image
      {:error, error} -> raise "failed to create image: #{inspect(error)}"
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
end

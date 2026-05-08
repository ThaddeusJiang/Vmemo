defmodule VmemoWeb.Api.V1.ImageControllerTest do
  @moduledoc """
  Image API tests
  """

  use VmemoWeb.ConnCase, async: true

  alias Ash
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageNote
  alias Vmemo.Memo.Note

  import Vmemo.AccountFixtures
  import VmemoWeb.ApiFixtures

  describe "POST /api/v1/images - Create image" do
    setup %{conn: conn} do
      user = user_fixture()
      raw_token = create_test_token(user)

      {:ok, conn: conn, user: user, raw_token: raw_token}
    end

    test "returns 400 when no file provided", %{conn: conn, raw_token: raw_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{})

      assert conn.status == 400
      assert json_response(conn, 400)["statusCode"] == 400
      assert json_response(conn, 400)["message"] == "No file provided"
    end

    test "returns 401 without token", %{conn: conn} do
      test_image_path = create_test_image()

      conn =
        post(conn, ~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: test_image_path,
            filename: "test.png",
            content_type: "image/png"
          }
        })

      assert conn.status == 401
    end

    test "returns 400 for invalid file type", %{conn: conn, raw_token: raw_token} do
      # Create a text file instead of image
      test_file_path = Path.join(System.tmp_dir!(), "test.txt")
      File.write!(test_file_path, "not an image")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: test_file_path,
            filename: "test.txt",
            content_type: "text/plain"
          }
        })

      assert conn.status == 400
    end
  end

  describe "GET /api/v1/images/:id - Show image" do
    setup %{conn: conn} do
      user = user_fixture()
      raw_token = create_test_token(user)

      {:ok, conn: conn, user: user, raw_token: raw_token}
    end

    test "returns 404 for non-existent image", %{conn: conn, raw_token: raw_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> get(~p"/api/v1/images/999999")

      assert conn.status == 404
      assert json_response(conn, 404)["statusCode"] == 404
      assert json_response(conn, 404)["message"] == "Image not found"
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/images/1")

      assert conn.status == 401
    end

    test "returns image detail page url for existing image", %{
      conn: conn,
      raw_token: raw_token,
      user: user
    } do
      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/show-image.png",
          note: "show image",
          caption: "caption",
          file_id: "show-image",
          user_id: user.id
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> get(~p"/api/v1/images/#{image.id}")

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_map(response)
      assert response["id"] == image.id
      assert String.starts_with?(response["url"], "http")
      assert String.contains?(response["url"], "/images/#{image.id}")
      refute Map.has_key?(response, "status")
      refute Map.has_key?(response, "data")
    end
  end

  describe "DELETE /api/v1/images/:id - Delete image" do
    setup %{conn: conn} do
      user = user_fixture()
      raw_token = create_test_token(user)

      {:ok, conn: conn, user: user, raw_token: raw_token}
    end

    test "returns 404 for non-existent image", %{conn: conn, raw_token: raw_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> delete(~p"/api/v1/images/999999")

      assert conn.status == 404
    end

    test "returns 401 without token", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/images/1")

      assert conn.status == 401
    end

    test "deletes image successfully when image has linked notes", %{
      conn: conn,
      user: user,
      raw_token: raw_token
    } do
      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/delete-linked-image.png",
          note: "image to delete",
          caption: "caption",
          file_id: "delete-linked-image",
          user_id: user.id
        })

      note = create_note!(%{text: "linked note", user_id: user.id})
      create_image_note!(image.id, note.id)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> delete(~p"/api/v1/images/#{image.id}")

      assert conn.status == 200
      assert json_response(conn, 200)["id"] == image.id
    end
  end

  # Helper functions

  defp create_test_image do
    # Create a simple 1x1 PNG image
    # PNG header + minimal data
    png_data =
      <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44,
        0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90,
        0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00, 0x0B, 0x13,
        0x00, 0x00, 0x0B, 0x13, 0x01, 0x00, 0x9A, 0x9C, 0x18, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44,
        0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x04, 0x01, 0x01, 0x01, 0x00, 0x00, 0x05, 0x00,
        0x01, 0x65, 0xA8, 0xE3, 0x25, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
        0x60, 0x82>>

    temp_file =
      Path.join([
        System.tmp_dir!(),
        "test_image_#{:rand.uniform(100_000)}.png"
      ])

    File.write!(temp_file, png_data)
    temp_file
  end

  defp create_image!(attrs) do
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, image} -> image
      {:error, error} -> raise "failed to create image: #{inspect(error)}"
    end
  end

  defp create_note!(attrs) do
    case Ash.create(Note, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, note} -> note
      {:error, error} -> raise "failed to create note: #{inspect(error)}"
    end
  end

  defp create_image_note!(image_id, note_id) do
    case Ash.create(ImageNote, %{image_id: image_id, note_id: note_id},
           action: :import,
           actor: nil,
           authorize?: false
         ) do
      {:ok, _link} -> :ok
      {:error, error} -> raise "failed to create image_note: #{inspect(error)}"
    end
  end
end

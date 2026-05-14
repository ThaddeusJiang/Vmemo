defmodule VmemoWeb.Api.V1.ImageControllerTest do
  @moduledoc """
  Image API tests
  """

  use VmemoWeb.ConnCase, async: false

  alias Ash
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageNote
  alias Vmemo.Memo.Note

  import Vmemo.AccountFixtures
  import VmemoWeb.ApiFixtures
  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

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

    test "accepts clipboard-style upload without extension", %{conn: conn, raw_token: raw_token} do
      test_image_path = create_test_image()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: test_image_path,
            filename: "clipboard",
            content_type: "application/octet-stream"
          }
        })

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_binary(response["id"])
      assert String.contains?(response["url"], "/images/")
    end

    test "accepts clipboard upload when temp path uses /private prefix", %{
      conn: conn,
      raw_token: raw_token
    } do
      test_image_path = create_test_image()

      private_prefixed_path =
        case test_image_path do
          "/var/" <> rest -> "/private/var/" <> rest
          _ -> test_image_path
        end

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: private_prefixed_path,
            filename: "clipboard",
            content_type: "application/octet-stream"
          }
        })

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_binary(response["id"])
    end

    test "accepts image/jpg content_type from clipboard clients", %{
      conn: conn,
      raw_token: raw_token
    } do
      test_image_path = create_test_image()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: test_image_path,
            filename: "clipboard",
            content_type: "image/jpg"
          }
        })

      assert conn.status == 200
    end

    test "accepts content_type with parameters", %{conn: conn, raw_token: raw_token} do
      test_image_path = create_test_image()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: test_image_path,
            filename: "clipboard",
            content_type: "image/jpeg; charset=binary"
          }
        })

      assert conn.status == 200
    end

    test "returns 400 when declared content_type mismatches detected image type", %{
      conn: conn,
      raw_token: raw_token
    } do
      test_image_path = create_test_image()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: test_image_path,
            filename: "clipboard",
            content_type: "text/plain"
          }
        })

      assert conn.status == 400

      assert json_response(conn, 400)["message"] ==
               "Invalid file type. Only image files are allowed"
    end

    test "accepts raw binary body upload with image content-type", %{
      conn: conn,
      raw_token: raw_token
    } do
      binary = File.read!(@fixture_image)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> put_req_header("content-type", "image/png")
        |> post(~p"/api/v1/images", binary)

      assert conn.status == 200
    end

    test "accepts data url payload in file field", %{conn: conn, raw_token: raw_token} do
      base64 =
        @fixture_image
        |> File.read!()
        |> Base.encode64()

      payload = "data:image/png;base64," <> base64

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{"file" => payload})

      assert conn.status == 200
    end

    test "accepts clipboard html file containing data-url image", %{
      conn: conn,
      raw_token: raw_token
    } do
      base64 =
        @fixture_image
        |> File.read!()
        |> Base.encode64()

      html = "<html><body><img src=\"data:image/png;base64,#{base64}\"></body></html>"

      html_path =
        Path.join(System.tmp_dir!(), "clipboard-test-#{System.unique_integer([:positive])}.html")

      File.write!(html_path, html)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: html_path,
            filename: "Clipboard May 14, 2026 at 1.16.html",
            content_type: "text/html"
          }
        })

      assert conn.status == 200
    end

    test "accepts clipboard html file containing remote image url", %{
      conn: conn,
      raw_token: raw_token
    } do
      html =
        "<html><body><img src=\"https://upload.wikimedia.org/wikipedia/en/4/4c/WALL-E_poster.jpg\"></body></html>"

      html_path =
        Path.join(
          System.tmp_dir!(),
          "clipboard-test-remote-#{System.unique_integer([:positive])}.html"
        )

      File.write!(html_path, html)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: html_path,
            filename: "Clipboard May 14, 2026 at 1.19.html",
            content_type: "text/html"
          }
        })

      assert conn.status == 200
    end

    test "returns 400 for clipboard html file without image src", %{
      conn: conn,
      raw_token: raw_token
    } do
      html_path =
        Path.join(
          System.tmp_dir!(),
          "clipboard-test-empty-#{System.unique_integer([:positive])}.html"
        )

      File.write!(html_path, "<html><body>no image</body></html>")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: html_path,
            filename: "Clipboard May 14, 2026 at 1.16.html",
            content_type: "text/html"
          }
        })

      assert conn.status == 400
    end

    test "returns 400 for clipboard html file with localhost image url", %{
      conn: conn,
      raw_token: raw_token
    } do
      html = "<html><body><img src=\"http://localhost:4000/images/logo.svg\"></body></html>"

      html_path =
        Path.join(
          System.tmp_dir!(),
          "clipboard-test-localhost-#{System.unique_integer([:positive])}.html"
        )

      File.write!(html_path, html)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: html_path,
            filename: "Clipboard blocked localhost.html",
            content_type: "text/html"
          }
        })

      assert conn.status == 400
    end

    test "returns 400 for clipboard html file with private network image url", %{
      conn: conn,
      raw_token: raw_token
    } do
      html = "<html><body><img src=\"http://192.168.1.2/example.jpg\"></body></html>"

      html_path =
        Path.join(
          System.tmp_dir!(),
          "clipboard-test-private-ip-#{System.unique_integer([:positive])}.html"
        )

      File.write!(html_path, html)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: html_path,
            filename: "Clipboard blocked private-ip.html",
            content_type: "text/html"
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
    temp_file = Path.join(System.tmp_dir!(), "test_image_#{:rand.uniform(100_000)}.png")
    File.cp!(@fixture_image, temp_file)
    temp_file
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
    url = Map.fetch!(attrs, :url)
    storage_path = url |> String.trim_leading("/") |> Path.expand()

    expected_prefix = Path.join(["storage", "v1", user_id, "images"]) |> Path.expand()

    if String.starts_with?(storage_path, expected_prefix <> "/") do
      File.mkdir_p!(Path.dirname(storage_path))

      unless File.exists?(storage_path) do
        File.cp!(@fixture_image, storage_path)
      end
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

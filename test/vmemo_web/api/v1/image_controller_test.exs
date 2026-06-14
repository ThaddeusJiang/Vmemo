defmodule VmemoWeb.Api.V1.ImageControllerTest do
  @moduledoc """
  Image API tests
  """

  # async: false — Oban :inline workers need shared DB sandbox (see Vmemo.DataCase.setup_sandbox/1).
  use VmemoWeb.ConnCase, async: false

  alias Ash
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageNote
  alias Vmemo.Memo.Note
  alias Vmemo.Storage

  import ExUnit.CaptureLog
  import Vmemo.AccountFixtures
  import VmemoWeb.ApiFixtures
  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")
  @ui_image_max_file_size Application.compile_env!(:vmemo, :image_upload_max_file_size)
  @api_multipart_body_limit @ui_image_max_file_size + 1_000_000

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

    test "accepts tiff clipboard upload from API clients", %{
      conn: conn,
      raw_token: raw_token,
      user: user
    } do
      test_image_path = create_test_tiff()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> post(~p"/api/v1/images", %{
          "file" => %Plug.Upload{
            path: test_image_path,
            filename: "Clipboard Jun 8, 2026 at 20.07.tiff",
            content_type: "image/tiff"
          }
        })

      assert conn.status == 200
      response = json_response(conn, 200)
      assert is_binary(response["id"])

      assert {:ok, image} = Image.get(response["id"], actor: user)
      assert String.ends_with?(image.url, ".png")
      refute String.ends_with?(image.url, ".tiff")
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

    test "accepts multipart image within UI size limit above Plug parser default", %{
      conn: conn,
      raw_token: raw_token
    } do
      file_binary = large_png_binary(20_000_000)
      {body, boundary} = multipart_body(file_binary)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-length", Integer.to_string(byte_size(body)))
        |> put_req_header("content-type", "multipart/form-data; boundary=#{boundary}")
        |> post(~p"/api/v1/images", body)

      assert conn.status == 200
      assert is_binary(json_response(conn, 200)["id"])
    end

    test "returns 413 standard JSON when multipart image exceeds UI size limit", %{
      conn: conn,
      raw_token: raw_token
    } do
      file_binary = large_png_binary(@ui_image_max_file_size + 1)
      {body, boundary} = multipart_body(file_binary)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-length", Integer.to_string(byte_size(body)))
        |> put_req_header("content-type", "multipart/form-data; boundary=#{boundary}")
        |> post(~p"/api/v1/images", body)

      assert json_response(conn, 413) == %{
               "statusCode" => 413,
               "statusMessage" => "Request Entity Too Large",
               "message" =>
                 "Uploaded image is #{format_test_size(@ui_image_max_file_size + 1)}, which exceeds the app limit of #{format_test_size(@ui_image_max_file_size)}. Compress the image or upload a smaller file, then try again."
             }
    end

    test "returns 413 standard JSON when multipart request exceeds API body limit", %{
      conn: conn,
      raw_token: raw_token
    } do
      file_binary = large_png_binary(@api_multipart_body_limit + 1)
      {body, boundary} = multipart_body(file_binary)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_token}")
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-length", Integer.to_string(byte_size(body)))
        |> put_req_header("content-type", "multipart/form-data; boundary=#{boundary}")
        |> post(~p"/api/v1/images", body)

      response = json_response(conn, 413)

      assert response["statusCode"] == 413
      assert response["statusMessage"] == "Request Entity Too Large"

      assert response["message"] =~
               "Uploaded request body is #{format_test_size(byte_size(body))}"

      assert response["message"] =~
               "API body limit of #{format_test_size(@api_multipart_body_limit)}"

      assert response["message"] =~
               "app image limit of #{format_test_size(@ui_image_max_file_size)}"

      assert response["message"] =~ "Compress the image or upload a smaller file, then try again."
    end

    test "logs API request and response summaries without sensitive payload", %{
      conn: conn,
      raw_token: raw_token
    } do
      binary = File.read!(@fixture_image)

      previous_level = Logger.level()

      log =
        try do
          Logger.configure(level: :info)

          capture_log([level: :info], fn ->
            conn
            |> put_req_header("authorization", "Bearer #{raw_token}")
            |> put_req_header("content-length", Integer.to_string(byte_size(binary)))
            |> put_req_header("content-type", "image/png")
            |> post(~p"/api/v1/images", binary)
          end)
        after
          Logger.configure(level: previous_level)
        end

      assert log =~ "api_request start method=POST path=/api/v1/images"
      assert log =~ "api_response sent method=POST path=/api/v1/images status=200"
      assert log =~ "request_content_length=#{byte_size(binary)}"
      refute log =~ raw_token
      refute log =~ binary
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

  defp create_test_tiff do
    temp_file = Path.join(System.tmp_dir!(), "test_image_#{:rand.uniform(100_000)}.tiff")
    File.write!(temp_file, tiff_binary())
    temp_file
  end

  defp tiff_binary do
    "SUkqAAoAAAD//w8AAAEDAAEAAAABAAAAAQEDAAEAAAABAAAAAgEDAAEAAAAQAAAAAwEDAAEAAAABAAAABgEDAAEAAAABAAAACgEDAAEAAAABAAAAEQEEAAEAAAAIAAAAEgEDAAEAAAABAAAAFQEDAAEAAAABAAAAFgEDAAEAAAABAAAAFwEEAAEAAAACAAAAHAEDAAEAAAABAAAAKQEDAAIAAAAAAAEAPgEFAAIAAAD0AAAAPwEFAAYAAADEAAAAAAAAAIXrUQAAAIAAw/WoAAAAAALNzEwAAAAAAc3MTAAAAIAAzcxMAAAAAAKPwvUAAAAAEDcaoAAAAAACK4cKAAAAIAA="
    |> Base.decode64!()
  end

  defp large_png_binary(size) when size >= 12 do
    png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0>>
    png_header <> :binary.copy(<<0>>, size - byte_size(png_header))
  end

  defp multipart_body(file_binary) do
    boundary = "vmemo-test-boundary-#{System.unique_integer([:positive])}"

    body =
      IO.iodata_to_binary([
        "--",
        boundary,
        "\r\n",
        "Content-Disposition: form-data; name=\"file\"; filename=\"large.png\"\r\n",
        "Content-Type: image/png\r\n\r\n",
        file_binary,
        "\r\n--",
        boundary,
        "\r\n",
        "Content-Disposition: form-data; name=\"note\"\r\n\r\n",
        "large image",
        "\r\n--",
        boundary,
        "--\r\n"
      ])

    {body, boundary}
  end

  defp format_test_size(bytes) do
    mb =
      bytes
      |> Kernel./(1_000_000)
      |> :erlang.float_to_binary(decimals: 2)

    "#{format_test_integer(bytes)} bytes (#{mb} MB)"
  end

  defp format_test_integer(integer) do
    integer
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
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
    {:ok, storage_path} = Storage.path_from_url(url)

    expected_prefix = Storage.path(["v1", user_id, "images"])

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

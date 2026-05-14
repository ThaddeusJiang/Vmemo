defmodule VmemoWeb.Api.V1.ImageController do
  @moduledoc """
  API V1 Image Controller

  Handles image CRUD operations
  """

  use VmemoWeb, :controller

  alias Plug.Conn.Status
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageStorage

  require Logger

  @doc """
  Create a new image

  POST /api/v1/images
  Content-Type: multipart/form-data

  Parameters:
  - file: Image file (required)
  - note: Note (optional)
  """
  def create(conn, params) do
    current_user = conn.assigns.current_user

    case handle_file_upload(conn, params) do
      {:ok, %{path: path, filename: filename} = upload_meta, conn} ->
        process_image_upload(conn, path, filename, params, current_user, upload_meta)

      {:error, reason} ->
        error_response(conn, 400, reason)
    end
  end

  @doc """
  Get image information

  GET /api/v1/images/:id
  """
  def show(conn, %{"id" => image_id}) do
    current_user = conn.assigns.current_user

    case Image.get_with_notes(image_id, current_user.id, actor: current_user) do
      {:ok, image} ->
        json(conn, image_response(image, conn))

      {:error, _reason} ->
        error_response(conn, 404, "Image not found")
    end
  end

  @doc """
  Delete image

  DELETE /api/v1/images/:id
  """
  def delete(conn, %{"id" => image_id}) do
    current_user = conn.assigns.current_user

    case Image.get_with_notes(image_id, current_user.id, actor: current_user) do
      {:ok, image} ->
        delete_response = %{id: image.id}

        case Image.destroy(image, actor: current_user) do
          :ok ->
            json(conn, delete_response)

          {:ok, _deleted} ->
            json(conn, delete_response)

          {:error, _reason} ->
            error_response(conn, 500, "Failed to delete image")
        end

      {:error, _reason} ->
        error_response(conn, 404, "Image not found")
    end
  end

  # Private functions

  defp handle_file_upload(conn, params) do
    case params do
      %{"file" => %Plug.Upload{} = upload} ->
        validate_and_process_upload(upload)

      %{"image" => %Plug.Upload{} = upload} ->
        validate_and_process_upload(upload)

      %{"file" => data_url} when is_binary(data_url) ->
        validate_and_process_base64_payload(data_url)

      %{"image" => data_url} when is_binary(data_url) ->
        validate_and_process_base64_payload(data_url)

      _ ->
        maybe_read_raw_body_upload(conn)
    end
    |> with_conn(conn)
  end

  defp validate_and_process_upload(%Plug.Upload{} = upload) do
    if clipboard_html_upload?(upload) do
      validate_and_process_clipboard_html(upload.path)
    else
      with {:ok, mime_type} <- validate_image_content(upload.path),
           :ok <- validate_upload_content_type(upload.content_type, mime_type) do
        filename = generate_filename(upload.filename, mime_type)
        {:ok, %{path: upload.path, filename: filename}}
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp clipboard_html_upload?(%Plug.Upload{content_type: content_type, filename: filename})
       when is_binary(content_type) and is_binary(filename) do
    normalize_content_type(content_type) == "text/html" and
      String.ends_with?(String.downcase(filename), ".html")
  end

  defp clipboard_html_upload?(_), do: false

  defp validate_and_process_clipboard_html(path) do
    with {:ok, html} <- File.read(path),
         {:ok, src} <- extract_img_src_from_html(html),
         {:ok, binary, mime_type} <- image_binary_from_src(src),
         :ok <- File.mkdir_p(System.tmp_dir!()),
         tmp_path <-
           Path.join(System.tmp_dir!(), "vmemo-upload-#{System.unique_integer([:positive])}"),
         :ok <- File.write(tmp_path, binary),
         {:ok, detected_mime_type} <- validate_image_content(tmp_path),
         :ok <- validate_upload_content_type(mime_type, detected_mime_type) do
      filename = generate_filename("clipboard", detected_mime_type)
      {:ok, %{path: tmp_path, filename: filename, cleanup?: true}}
    else
      {:error, _reason} -> {:error, "Invalid image format"}
    end
  end

  defp extract_img_src_from_html(html) when is_binary(html) do
    case Regex.run(~r/<img[^>]+src=["']([^"']+)["']/i, html) do
      [_, src] when is_binary(src) and src != "" ->
        {:ok, html_unescape(src)}

      _ -> {:error, :missing_img_src}
    end
  end

  defp html_unescape(src) when is_binary(src) do
    src
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
  end

  defp image_binary_from_src("data:" <> _ = data_url) do
    decode_base64_payload(data_url)
  end

  defp image_binary_from_src("http://" <> _ = url), do: fetch_image_binary(url)
  defp image_binary_from_src("https://" <> _ = url), do: fetch_image_binary(url)
  defp image_binary_from_src(_), do: {:error, :unsupported_src}

  defp fetch_image_binary(url) do
    with :ok <- validate_remote_image_url(url),
         {:ok, %Req.Response{} = response} <-
           Req.get(url,
             redirect: true,
             max_redirects: 2,
             retry: false,
             receive_timeout: 5_000,
             connect_options: [timeout: 3_000]
           ),
         status <- response.status,
         body <- response.body,
         true <- status in 200..299,
         true <- is_binary(body),
         true <- byte_size(body) <= max_remote_image_bytes() do
      header_content_type = extract_content_type_from_response(response)

      mime_type =
        if header_content_type == "", do: "application/octet-stream", else: header_content_type

      {:ok, body, mime_type}
    else
      false -> {:error, :invalid_remote_image}
      {:error, _reason} -> {:error, :fetch_failed}
    end
  end

  defp max_remote_image_bytes, do: 10 * 1024 * 1024

  defp validate_remote_image_url(url) when is_binary(url) do
    with %URI{scheme: scheme, host: host} <- URI.parse(url),
         true <- scheme in ["http", "https"],
         true <- is_binary(host) and host != "",
         :ok <- validate_remote_host(host) do
      :ok
    else
      _ -> {:error, :invalid_remote_url}
    end
  end

  defp validate_remote_host(host) do
    normalized = String.downcase(host)

    if normalized in ["localhost", "localhost.localdomain"] do
      {:error, :blocked_host}
    else
      resolve_and_validate_host_ips(host)
    end
  end

  defp resolve_and_validate_host_ips(host) do
    host_charlist = String.to_charlist(host)

    case :inet.gethostbyname(host_charlist, :inet) do
      {:ok, {:hostent, _name, _aliases, :inet, _len, addresses}} ->
        validate_resolved_addresses(addresses)

      {:error, _} ->
        case :inet.gethostbyname(host_charlist, :inet6) do
          {:ok, {:hostent, _name, _aliases, :inet6, _len, addresses}} ->
            validate_resolved_addresses(addresses)

          {:error, _} ->
            {:error, :dns_resolution_failed}
        end
    end
  end

  defp validate_resolved_addresses(addresses) when is_list(addresses) do
    if addresses == [] or Enum.any?(addresses, &private_or_local_ip?/1) do
      {:error, :blocked_ip}
    else
      :ok
    end
  end

  defp private_or_local_ip?({127, _, _, _}), do: true
  defp private_or_local_ip?({10, _, _, _}), do: true
  defp private_or_local_ip?({192, 168, _, _}), do: true
  defp private_or_local_ip?({169, 254, _, _}), do: true
  defp private_or_local_ip?({172, second, _, _}) when second in 16..31, do: true
  defp private_or_local_ip?({0, _, _, _}), do: true
  defp private_or_local_ip?({100, second, _, _}) when second in 64..127, do: true
  defp private_or_local_ip?({_, _, _, _, _, _, _, 1}), do: true
  defp private_or_local_ip?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp private_or_local_ip?({0xFE80, _, _, _, _, _, _, _}), do: true
  defp private_or_local_ip?({0xFC00, _, _, _, _, _, _, _}), do: true
  defp private_or_local_ip?({0xFD00, _, _, _, _, _, _, _}), do: true
  defp private_or_local_ip?(_), do: false

  defp extract_content_type_from_response(%Req.Response{} = response) do
    response
    |> Req.Response.get_header("content-type")
    |> case do
      [] -> ["application/octet-stream"]
      values -> values
    end
    |> List.first()
    |> to_string()
    |> normalize_content_type()
  end

  defp validate_and_process_base64_payload(data_url) do
    with {:ok, binary, mime_type} <- decode_base64_payload(data_url),
         :ok <- validate_supported_mime_type(mime_type),
         :ok <- File.mkdir_p(System.tmp_dir!()),
         tmp_path <-
           Path.join(System.tmp_dir!(), "vmemo-upload-#{System.unique_integer([:positive])}"),
         :ok <- File.write(tmp_path, binary),
         {:ok, mime_type_from_content} <- validate_image_content(tmp_path),
         :ok <- validate_upload_content_type(mime_type, mime_type_from_content) do
      filename = generate_filename("clipboard", mime_type_from_content)
      {:ok, %{path: tmp_path, filename: filename, cleanup?: true}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_base64_payload("data:" <> payload) do
    case String.split(payload, ",", parts: 2) do
      [meta, encoded] ->
        mime_type = meta |> String.split(";") |> List.first() |> normalize_content_type()

        case Base.decode64(encoded) do
          {:ok, binary} -> {:ok, binary, mime_type}
          :error -> {:error, "Invalid file payload"}
        end

      _ ->
        {:error, "Invalid file payload"}
    end
  end

  defp decode_base64_payload(_), do: {:error, "Invalid file payload"}

  defp maybe_read_raw_body_upload(conn) do
    content_type =
      conn
      |> get_req_header("content-type")
      |> List.first()
      |> normalize_content_type()

    if content_type in supported_mime_types() or content_type == "application/octet-stream" do
      with {:ok, binary, _conn} <- Plug.Conn.read_body(conn),
           :ok <- validate_non_empty_binary(binary),
           :ok <- File.mkdir_p(System.tmp_dir!()),
           tmp_path <-
             Path.join(System.tmp_dir!(), "vmemo-upload-#{System.unique_integer([:positive])}"),
           :ok <- File.write(tmp_path, binary),
           {:ok, detected_mime_type} <- validate_image_content(tmp_path),
           :ok <- validate_upload_content_type(content_type, detected_mime_type) do
        filename = generate_filename("clipboard", detected_mime_type)
        {:ok, %{path: tmp_path, filename: filename, cleanup?: true}}
      else
        {:error, _reason} -> {:error, "Invalid image format"}
        {:more, _partial, _conn} -> {:error, "Invalid image format"}
      end
    else
      {:error, "No file provided"}
    end
  end

  defp with_conn({:ok, upload_meta}, conn), do: {:ok, upload_meta, conn}
  defp with_conn({:error, _reason} = error, _conn), do: error

  defp validate_image_content(path) do
    with true <- safe_upload_path?(path),
         {:ok, content} <- read_file_header(path, 12) do
      case detect_mime_type_from_binary(content) do
        nil -> {:error, "Invalid image format"}
        mime_type -> {:ok, mime_type}
      end
    else
      false ->
        {:error, "Invalid upload path"}

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end

  defp validate_upload_content_type(content_type, detected_mime_type)
       when content_type in [nil, "", "application/octet-stream"] do
    if detected_mime_type in supported_mime_types() do
      :ok
    else
      {:error, "Invalid file type. Only image files are allowed"}
    end
  end

  defp validate_upload_content_type(content_type, detected_mime_type)
       when is_binary(content_type) do
    normalized_content_type = normalize_content_type(content_type)

    if normalized_content_type in supported_mime_types() and
         detected_mime_type in supported_mime_types() do
      :ok
    else
      {:error, "Invalid file type. Only image files are allowed"}
    end
  end

  defp validate_upload_content_type(_content_type, _detected_mime_type),
    do: {:error, "Invalid file type. Only image files are allowed"}

  defp supported_mime_types, do: ~w(image/png image/jpeg image/jpg image/gif image/webp)

  defp normalize_content_type(content_type) when is_binary(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> List.first()
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp validate_supported_mime_type(mime_type) do
    if mime_type in supported_mime_types() do
      :ok
    else
      {:error, "Invalid file type. Only image files are allowed"}
    end
  end

  defp validate_non_empty_binary(binary) when is_binary(binary) and byte_size(binary) > 0, do: :ok
  defp validate_non_empty_binary(_), do: {:error, "No file provided"}

  defp safe_upload_path?(path) when is_binary(path) do
    normalized_upload_path = normalize_private_tmp_path(Path.expand(path))
    normalized_tmp_root = normalize_private_tmp_path(Path.expand(System.tmp_dir!()))

    String.starts_with?(normalized_upload_path, normalized_tmp_root <> "/")
  end

  defp safe_upload_path?(_), do: false

  defp normalize_private_tmp_path("/private" <> rest), do: rest
  defp normalize_private_tmp_path(path), do: path

  defp read_file_header(path, bytes) when is_binary(path) and is_integer(bytes) and bytes > 0 do
    case :file.open(String.to_charlist(path), [:read, :binary]) do
      {:ok, io} ->
        try do
          case :file.read(io, bytes) do
            {:ok, data} -> {:ok, data}
            :eof -> {:error, :eof}
            {:error, _} = error -> error
          end
        after
          :file.close(io)
        end

      {:error, _} = error ->
        error
    end
  end

  defp generate_filename(original_filename, mime_type) do
    uuid =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> String.replace(~r/(.{8})(.{4})(.{4})(.{4})(.{12})/, "\\1-\\2-\\3-\\4-\\5")

    extension = pick_upload_extension(original_filename, mime_type)
    "#{uuid}#{extension}"
  end

  defp pick_upload_extension(original_filename, mime_type) do
    case Path.extname(original_filename) |> String.downcase() do
      ext when ext in ~w(.png .jpg .jpeg .gif .webp) -> ext
      _ -> mime_type_to_extension(mime_type)
    end
  end

  defp mime_type_to_extension("image/png"), do: ".png"
  defp mime_type_to_extension("image/jpeg"), do: ".jpg"
  defp mime_type_to_extension("image/gif"), do: ".gif"
  defp mime_type_to_extension("image/webp"), do: ".webp"
  defp mime_type_to_extension(_), do: ".jpg"

  defp detect_mime_type_from_binary(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"

  defp detect_mime_type_from_binary(
         <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>
       ),
       do: "image/png"

  defp detect_mime_type_from_binary(<<"GIF87a", _::binary>>), do: "image/gif"
  defp detect_mime_type_from_binary(<<"GIF89a", _::binary>>), do: "image/gif"

  defp detect_mime_type_from_binary(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>),
    do: "image/webp"

  defp detect_mime_type_from_binary(_), do: nil

  defp process_image_upload(conn, path, filename, params, current_user, upload_meta) do
    user_id = to_string(current_user.id)

    try do
      {:ok, dest} = ImageStorage.cp_file(path, user_id, filename)
      note = Map.get(params, "note", "")

      attrs = %{
        note: note,
        url: Path.join("/", dest),
        file_id: filename,
        user_id: user_id,
        inner_purpose: nil
      }

      create_image(conn, attrs, current_user)
    after
      if Map.get(upload_meta, :cleanup?, false) do
        _ = File.rm(path)
      end
    end
  end

  defp create_image(conn, attrs, current_user) do
    case Image.import(attrs, actor: current_user) do
      {:ok, image} ->
        json(conn, image_response(image, conn))

      {:error, error} ->
        Logger.error("Failed to create image: #{inspect(error)}")
        error_response(conn, 500, "Failed to create image")
    end
  end

  defp image_response(image, conn) do
    %{
      id: image.id,
      url: url(conn, ~p"/images/#{image.id}"),
      note: image.note,
      inserted_at: image.inserted_at
    }
  end

  defp error_response(conn, status_code, message) do
    conn
    |> put_status(status_code)
    |> json(%{
      statusCode: status_code,
      statusMessage: Status.reason_phrase(status_code),
      message: message
    })
  end
end

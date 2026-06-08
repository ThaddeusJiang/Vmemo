defmodule VmemoWeb.MultipartParser do
  @moduledoc false

  import Plug.Conn

  alias Plug.Conn.Status

  @behaviour Plug.Parsers
  @api_body_limit_buffer 1_000_000
  @multipart Plug.Parsers.MULTIPART

  @impl true
  def init(opts), do: opts

  @impl true
  def parse(conn, "multipart", subtype, headers, opts) do
    opts =
      opts
      |> Keyword.put(:length, api_multipart_body_limit())
      |> @multipart.init()

    case @multipart.parse(conn, "multipart", subtype, headers, opts) do
      {:error, :too_large, conn} ->
        {:ok, %{}, too_large_response(conn)}

      result ->
        result
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts), do: {:next, conn}

  defp too_large_response(conn) do
    status_code = 413
    status_message = Status.reason_phrase(status_code)
    message = api_body_too_large_message(request_content_length(conn))

    body =
      Phoenix.json_library().encode!(%{
        statusCode: status_code,
        statusMessage: status_message,
        message: message
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code, body)
    |> halt()
  end

  defp request_content_length(conn) do
    conn
    |> get_req_header("content-length")
    |> List.first()
    |> parse_positive_integer()
  end

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> integer
      _other -> nil
    end
  end

  defp parse_positive_integer(_value), do: nil

  defp api_multipart_body_limit do
    Application.fetch_env!(:vmemo, :image_upload_max_file_size) + @api_body_limit_buffer
  end

  defp api_body_too_large_message(size) when is_integer(size) and size >= 0 do
    "Uploaded request body is #{format_size(size)}, which exceeds the API body limit of #{format_size(api_multipart_body_limit())} and the app image limit of #{format_size(Application.fetch_env!(:vmemo, :image_upload_max_file_size))}. Compress the image or upload a smaller file, then try again."
  end

  defp api_body_too_large_message(_size) do
    "Uploaded request body is too large. The API body limit is #{format_size(api_multipart_body_limit())} and the app image limit is #{format_size(Application.fetch_env!(:vmemo, :image_upload_max_file_size))}. Compress the image or upload a smaller file, then try again."
  end

  defp format_size(bytes) do
    mb =
      bytes
      |> Kernel./(1_000_000)
      |> :erlang.float_to_binary(decimals: 2)

    "#{format_integer(bytes)} bytes (#{mb} MB)"
  end

  defp format_integer(integer) do
    integer
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end
end

defmodule VmemoWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :vmemo
  require Logger

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_vmemo_key",
    signing_salt: "uAosw4Nt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :vmemo,
    gzip: false,
    only: VmemoWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

    plug AshAi.Mcp.Dev,
      # see the note below on protocol versions below
      protocol_version_statement: "2024-11-05",
      otp_app: :vmemo

    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :vmemo
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug :log_api_request

  plug Plug.Parsers,
    parsers: [:urlencoded, VmemoWeb.MultipartParser, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug Sentry.PlugContext
  plug VmemoWeb.Router

  defp log_api_request(%Plug.Conn{request_path: "/api/" <> _} = conn, _opts) do
    start_time = System.monotonic_time()

    Logger.info(
      "api_request start method=#{conn.method} path=#{conn.request_path} request_content_type=#{request_content_type(conn)} request_content_length=#{request_content_length(conn)}"
    )

    Plug.Conn.register_before_send(conn, fn conn ->
      duration_ms =
        System.monotonic_time()
        |> Kernel.-(start_time)
        |> System.convert_time_unit(:native, :millisecond)

      Logger.info(
        "api_response sent method=#{conn.method} path=#{conn.request_path} status=#{conn.status} duration_ms=#{duration_ms} response_content_type=#{response_content_type(conn)} user_id=#{user_id(conn)}"
      )

      conn
    end)
  end

  defp log_api_request(conn, _opts), do: conn

  defp request_content_type(conn) do
    conn
    |> Plug.Conn.get_req_header("content-type")
    |> List.first()
    |> empty_to_unknown()
  end

  defp request_content_length(conn) do
    conn
    |> Plug.Conn.get_req_header("content-length")
    |> List.first()
    |> empty_to_unknown()
  end

  defp response_content_type(conn) do
    conn.resp_headers
    |> List.keyfind("content-type", 0)
    |> case do
      {_key, value} -> empty_to_unknown(value)
      nil -> "unknown"
    end
  end

  defp user_id(%Plug.Conn{assigns: %{current_user: %{id: id}}}) when not is_nil(id), do: id
  defp user_id(_conn), do: "none"

  defp empty_to_unknown(value) when is_binary(value) and value != "", do: value
  defp empty_to_unknown(_value), do: "unknown"
end

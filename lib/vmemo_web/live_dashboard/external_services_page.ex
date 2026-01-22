defmodule VmemoWeb.LiveDashboard.ExternalServicesPage do
  use Phoenix.LiveDashboard.PageBuilder

  @health_timeout_ms 2_000
  @services [
    %{
      id: :typesense,
      name: "Typesense",
      url_key: :typesense_url,
      health_path: "/health"
    },
    %{
      id: :moondream,
      name: "Moondream",
      url_key: :moondream_url,
      health_path: "/health"
    }
  ]

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def menu_link(_session, _capabilities), do: {:ok, "External Services"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_services(socket)}
  end

  @impl true
  def handle_refresh(socket) do
    {:noreply, assign_services(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="row">
      <div class="col-12">
        <div class="card mb-4">
          <div class="card-body">
            <h5>External Services</h5>
            <p>Last checked: <%= format_checked_at(@checked_at) %></p>
            <div class="table-responsive">
              <table class="table table-hover">
                <thead>
                  <tr>
                    <th>Service</th>
                    <th>URL</th>
                    <th>Status</th>
                    <th>Detail</th>
                    <th>Response Time</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={service <- @services}>
                    <td><%= service.name %></td>
                    <td><pre><%= service.url || "Not configured" %></pre></td>
                    <td>
                      <span class={status_badge_class(service.status)}>
                        <%= service.status %>
                      </span>
                    </td>
                    <td><pre><%= service.detail || "-" %></pre></td>
                    <td><%= format_response_time(service.response_time_ms) %></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp assign_services(socket) do
    socket
    |> assign(:services, Enum.map(@services, &check_service/1))
    |> assign(:checked_at, NaiveDateTime.utc_now())
  end

  defp check_service(service) do
    url = Application.get_env(:vmemo, service.url_key)

    cond do
      is_nil(url) ->
        Map.merge(service, %{
          url: nil,
          status: "Not configured",
          detail: "Missing config #{inspect(service.url_key)}",
          response_time_ms: nil
        })

      not valid_url?(url) ->
        Map.merge(service, %{
          url: url,
          status: "Invalid URL",
          detail: "Expected http or https URL",
          response_time_ms: nil
        })

      true ->
        {status, detail, response_time_ms} = check_health(url, service.health_path)

        Map.merge(service, %{
          url: url,
          status: status,
          detail: detail,
          response_time_ms: response_time_ms
        })
    end
  end

  defp check_health(url, health_path) do
    start_ms = System.monotonic_time(:millisecond)

    req =
      Req.new(
        base_url: url,
        url: health_path,
        receive_timeout: @health_timeout_ms,
        retry: false
      )

    result = Req.get(req)
    duration_ms = System.monotonic_time(:millisecond) - start_ms

    case result do
      {:ok, %{status: status}} when status in 200..299 ->
        {"Healthy", "HTTP #{status}", duration_ms}

      {:ok, %{status: status}} ->
        {"Unhealthy", "HTTP #{status}", duration_ms}

      {:error, %Req.TransportError{reason: reason}} ->
        {"Unreachable", format_reason(reason), duration_ms}

      {:error, reason} ->
        {"Error", format_reason(reason), duration_ms}
    end
  end

  defp valid_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        true

      _ ->
        false
    end
  end

  defp valid_url?(_), do: false

  defp format_response_time(nil), do: "-"
  defp format_response_time(ms), do: "#{ms} ms"

  defp format_checked_at(nil), do: "-"

  defp format_checked_at(datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  defp status_badge_class(status) do
    base = "badge"

    case status do
      "Healthy" -> base <> " badge-success"
      "Unhealthy" -> base <> " badge-error"
      "Unreachable" -> base <> " badge-error"
      "Error" -> base <> " badge-error"
      "Invalid URL" -> base <> " badge-warning"
      "Not configured" -> base <> " badge-warning"
      _ -> base <> " badge-ghost"
    end
  end

  defp format_reason(reason) do
    case reason do
      :connection_refused -> "connection_refused"
      :timeout -> "timeout"
      _ -> inspect(reason)
    end
  end
end

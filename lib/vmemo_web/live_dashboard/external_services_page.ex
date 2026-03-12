defmodule VmemoWeb.LiveDashboard.ExternalServicesPage do
  use Phoenix.LiveDashboard.PageBuilder

  alias SmallSdk.Moondream
  alias VmemoWeb.LiveDashboard.ExternalServicesCache
  alias VmemoWeb.Utils.Datetime

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
      url_key: :moondream_url
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
  def handle_event("test-service", %{"id" => id}, socket) do
    service_id = String.to_existing_atom(id)

    services = update_service(socket.assigns.services, service_id, &check_service/1)

    checked_at = Datetime.now_iso_datetime()
    ExternalServicesCache.set_checked_at(checked_at)

    {:noreply, socket |> assign(:services, services) |> assign(:checked_at, checked_at)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="row">
      <div class="col-12">
        <div class="card mb-4">
          <div class="card-body">
            <h5>External Services</h5>
            <p>
              Last checked:
              <span
                id="external-services-last-checked"
                data-iso={Datetime.format_datetime(@checked_at)}
                phx-hook="FormatDatetime"
              >
                {Datetime.format_datetime_human(@checked_at)}
              </span>
            </p>
            <div class="table-responsive">
              <table class="table table-hover">
                <thead>
                  <tr>
                    <th>Service</th>
                    <th>Health URL</th>
                    <th>Status</th>
                    <th>Detail</th>
                    <th>Response Time</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={service <- @services}>
                    <td>{service.name}</td>
                    <td><pre><%= format_health_url(service) %></pre></td>
                    <td>
                      <span class={status_badge_class(service.status)}>
                        {service.status}
                      </span>
                    </td>
                    <td><pre><%= service.detail || "-" %></pre></td>
                    <td>{format_response_time(service.response_time_ms)}</td>
                    <td>
                      <button
                        class="btn btn-sm btn-outline"
                        phx-click="test-service"
                        phx-value-id={service.id}
                      >
                        Test
                      </button>
                    </td>
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
    %{checked_at: checked_at, services: cached_services} = ExternalServicesCache.get_state()

    services =
      Enum.map(@services, fn service_def ->
        base = init_service(service_def)
        dynamic = Map.get(cached_services, service_def.id, %{})
        Map.merge(base, dynamic)
      end)

    socket
    |> assign(:services, services)
    |> assign(:checked_at, checked_at)
  end

  defp init_service(service) do
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
        Map.merge(service, %{
          url: url,
          status: "Not checked",
          detail: nil,
          response_time_ms: nil
        })
    end
  end

  defp check_service(service) do
    base = init_service(service)

    cond do
      base.status in ["Not configured", "Invalid URL"] ->
        base

      true ->
        case check_health(base, base.url) do
          {:ok, _detail, response_time_ms} ->
            ExternalServicesCache.update_service(base.id, %{
              status: "ok",
              detail: nil,
              response_time_ms: response_time_ms
            })

            Map.merge(base, %{
              status: "ok",
              detail: nil,
              response_time_ms: response_time_ms
            })

          {:error, detail, response_time_ms} ->
            ExternalServicesCache.update_service(base.id, %{
              status: "error",
              detail: detail,
              response_time_ms: response_time_ms
            })

            Map.merge(base, %{
              status: "error",
              detail: detail,
              response_time_ms: response_time_ms
            })
        end
    end
  end

  defp update_service(services, id, fun) do
    Enum.map(services, fn service ->
      if service.id == id, do: fun.(service), else: service
    end)
  end

  defp check_health(%{id: :moondream}, _url) do
    start_ms = System.monotonic_time(:millisecond)

    image_base64 = moondream_sample_image_base64()

    result = Moondream.caption(image_base64, length: "short", mime_type: "image/png")
    duration_ms = System.monotonic_time(:millisecond) - start_ms

    case result do
      {:ok, _caption} ->
        {:ok, nil, duration_ms}

      {:error, reason} ->
        {:error, inspect(reason), duration_ms}
    end
  end

  defp check_health(service, url) do
    start_ms = System.monotonic_time(:millisecond)

    health_path = Map.get(service, :health_path, "/")

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
        {:ok, nil, duration_ms}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}", duration_ms}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, format_reason(reason), duration_ms}

      {:error, reason} ->
        {:error, format_reason(reason), duration_ms}
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

  defp format_health_url(%{url: nil}), do: "Not configured"

  defp format_health_url(%{url: url} = service) when is_binary(url) do
    path = Map.get(service, :health_path, "/")

    cond do
      is_nil(path) or path in ["", "/"] ->
        url

      true ->
        base = String.trim_trailing(url, "/")
        rel = String.trim_leading(path, "/")
        base <> "/" <> rel
    end
  end

  defp moondream_sample_image_base64 do
    # 1x1 red PNG
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jgfsAAAAASUVORK5CYII="
  end

  defp format_response_time(nil), do: "-"
  defp format_response_time(ms), do: "#{ms} ms"

  defp status_badge_class(status) do
    base = "badge"

    case status do
      "ok" -> base <> " badge-success"
      "error" -> base <> " badge-error"
      "Invalid URL" -> base <> " badge-warning"
      "Not configured" -> base <> " badge-warning"
      _ -> base <> " badge-ghost"
    end
  end

  defp format_reason(reason) do
    case reason do
      :connection_refused -> "connection_refused"
      :timeout -> "timeout"
      :closed -> "connection closed by server (no response)"
      _ -> inspect(reason)
    end
  end
end

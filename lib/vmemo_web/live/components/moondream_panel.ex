defmodule VmemoWeb.LiveComponents.MoondreamPanel do
  @moduledoc false
  use VmemoWeb, :live_component

  alias Vmemo.Ai.VisionRequest

  @function_types ["query", "caption", "point", "detect", "segment"]

  defp function_types, do: @function_types

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:prompt, "")
     |> assign(:function, "query")
     |> assign(:requests, [])
     |> assign(:loading_requests, MapSet.new())}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:requests, fn -> [] end)
     |> assign_new(:loading_requests, fn -> MapSet.new() end)}
  end

  @impl true
  def handle_event("change", %{"moondream" => params}, socket) do
    prompt = Map.get(params, "prompt", socket.assigns.prompt)
    function = Map.get(params, "function", socket.assigns.function)

    if segment_disabled?(function) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:prompt, prompt)
       |> assign(:function, function)}
    end
  end

  @impl true
  def handle_event("set-prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :prompt, prompt)}
  end

  @impl true
  def handle_event("submit", %{"moondream" => params}, socket) do
    user = socket.assigns.current_user
    image = socket.assigns.image
    function = socket.assigns.function
    prompt = Map.get(params, "prompt", "") |> String.trim()
    prompt = if prompt == "", do: socket.assigns.prompt, else: prompt

    if segment_disabled?(function) do
      {:noreply, socket}
    else
      case VisionRequest.create(
             %{
               image_id: image.id,
               user_id: user.id,
               function_type: function,
               prompt: prompt
             },
             actor: user
           ) do
        {:ok, request} ->
          loading_requests = MapSet.put(socket.assigns.loading_requests, request.id)

          send(self(), {:moondream_request_submitted, request})

          {:noreply,
           socket
           |> assign(:loading_requests, loading_requests)
           |> assign(:prompt, "")}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, socket |> put_flash(:error, "Failed to create request: #{error_msg}")}
      end
    end
  end

  @impl true
  def handle_event("retry-request", %{"request_id" => request_id}, socket) do
    user = socket.assigns.current_user

    case Ash.get(VisionRequest, request_id, actor: user) do
      {:ok, %{status: "failed"} = request} ->
        retry_failed_request(socket, user, request)

      {:ok, _request} ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp segment_disabled?(function), do: function == "segment"

  defp retry_failed_request(socket, user, request) do
    case VisionRequest.retry(request, %{}, actor: user) do
      {:ok, updated_request} ->
        loading_requests = MapSet.put(socket.assigns.loading_requests, updated_request.id)
        updated_requests = mark_request_pending(socket.assigns.requests, updated_request.id)

        send(self(), {:moondream_request_submitted, updated_request})

        {:noreply,
         socket
         |> assign(:loading_requests, loading_requests)
         |> assign(:requests, updated_requests)}
    end
  end

  defp mark_request_pending(requests, request_id) do
    Enum.map(requests, fn req ->
      if req.id == request_id do
        Map.merge(req, %{status: "pending", error_message: nil})
      else
        req
      end
    end)
  end

  defp format_changeset_errors(changeset) do
    case changeset do
      %Ash.Error.Invalid{errors: errors} ->
        Enum.map_join(errors, "; ", &format_changeset_error/1)

      _ ->
        "Failed to create request"
    end
  end

  defp format_error_message(error_message) when is_binary(error_message) do
    error_message_lower = String.downcase(error_message)
    is_transport_error = String.contains?(error_message, "Req.TransportError")

    cond do
      is_transport_error and String.contains?(error_message_lower, "timeout") ->
        "Request timeout. Please try again."

      is_transport_error ->
        format_transport_error_reason(error_message)

      String.contains?(error_message, "Req.Error") ->
        "Request failed. Please try again."

      String.contains?(error_message_lower, "timeout") ->
        "Request timeout. Please try again."

      String.contains?(error_message_lower, "connection") ->
        "Connection error. Please check your network and try again."

      String.contains?(error_message_lower, "network") ->
        "Network error. Please check your connection and try again."

      true ->
        format_unknown_error_message(error_message)
    end
  end

  defp format_error_message(_), do: "An error occurred. Please try again."

  defp format_changeset_error(%Ash.Error.Changes.Required{field: field}),
    do: "#{field} is required"

  defp format_changeset_error(%Ash.Error.Changes.InvalidAttribute{
         field: field,
         message: message
       }),
       do: "#{field}: #{message}"

  defp format_changeset_error(_), do: "Validation failed"

  defp format_transport_error_reason(error_message) do
    case Regex.run(~r/reason:\s*:(\w+)/, error_message) do
      [_, reason] ->
        reason_formatted = reason |> String.replace("_", " ") |> String.capitalize()
        "Connection error: #{reason_formatted}"

      _ ->
        "Network error occurred"
    end
  end

  defp format_unknown_error_message(error_message) do
    if String.contains?(error_message, "%") or String.contains?(error_message, "{") do
      "An error occurred. Please try again."
    else
      error_message
    end
  end

  defp has_detection_results?(requests) do
    Enum.any?(requests, fn req ->
      req.status == "completed" and
        req.function_type in ["detect", "segment"] and
        is_map(req.result) and
        is_list(Map.get(req.result, "objects"))
    end)
  end

  defp get_detection_tags(requests) do
    requests
    |> Enum.filter(fn req ->
      req.status == "completed" and
        req.function_type in ["detect", "segment"] and
        is_map(req.result)
    end)
    |> Enum.flat_map(fn req ->
      case Map.get(req.result, "objects") do
        objects when is_list(objects) ->
          objects
          |> Enum.map(&Map.get(&1, "label"))
          |> Enum.filter(&is_binary/1)

        _ ->
          []
      end
    end)
    |> Enum.uniq()
  end

  defp format_request_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_result(result, _function_type) when is_binary(result), do: result

  defp format_result(%{"text" => text}, _function_type) when is_binary(text), do: text

  defp format_result(result, function_type) when is_map(result) do
    case function_type do
      "detect" -> format_detection_result(result)
      "segment" -> format_detection_result(result)
      "point" -> format_point_result(result)
      _ -> Jason.encode!(result, pretty: true)
    end
  end

  defp format_result(result, _function_type), do: inspect(result)

  defp format_detection_result(%{"objects" => objects}) when is_list(objects) do
    Enum.map_join(objects, "\n", fn obj ->
      label = Map.get(obj, "label", "unknown")
      count = Map.get(obj, "count", 1)
      "#{label}: #{count}"
    end)
  end

  defp format_detection_result(result), do: Jason.encode!(result, pretty: true)

  defp format_point_result(%{"x" => x, "y" => y}) do
    "Point: (#{x}, #{y})"
  end

  defp format_point_result(result), do: Jason.encode!(result, pretty: true)

  defp extract_point_coordinates(result) when is_map(result) do
    case extract_multiple_points(result) do
      {:multiple, _points} = multiple ->
        multiple

      nil ->
        extract_single_point_coordinates(result)
    end
  end

  defp extract_point_coordinates(_), do: nil

  defp extract_multiple_points(%{"points" => points}) when is_list(points) do
    normalized_points =
      points
      |> Enum.filter(&has_xy_coordinates?/1)
      |> Enum.map(&point_tuple_from_map/1)
      |> Enum.reject(&is_nil/1)

    if normalized_points == [], do: nil, else: {:multiple, normalized_points}
  end

  defp extract_multiple_points(_result), do: nil

  defp extract_single_point_coordinates(result) do
    [
      point_tuple_from_map(result),
      point_tuple_from_nested_map(result, "point"),
      point_tuple_from_nested_map(result, "coordinates")
    ]
    |> Enum.find_value(&wrap_single_point/1)
  end

  defp point_tuple_from_nested_map(result, key) do
    case Map.get(result, key) do
      nested when is_map(nested) -> point_tuple_from_map(nested)
      _ -> nil
    end
  end

  defp point_tuple_from_map(map) when is_map(map) do
    with true <- has_xy_coordinates?(map),
         x when not is_nil(x) <- normalize_coordinate(Map.get(map, "x")),
         y when not is_nil(y) <- normalize_coordinate(Map.get(map, "y")) do
      {x, y}
    else
      _ -> nil
    end
  end

  defp point_tuple_from_map(_), do: nil

  defp has_xy_coordinates?(map),
    do: is_map(map) and Map.has_key?(map, "x") and Map.has_key?(map, "y")

  defp wrap_single_point(nil), do: nil
  defp wrap_single_point(point), do: {:single, point}

  defp normalize_coordinate(value) when is_number(value), do: value

  defp normalize_coordinate(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp normalize_coordinate(_), do: nil

  defp extract_detection_boxes(result) when is_map(result) do
    result
    |> extract_detection_objects()
    |> Enum.filter(&is_map/1)
    |> Enum.map(&extract_single_detection_box/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_detection_boxes(_), do: []

  defp extract_detection_objects(result) do
    ["data", "objects", "detections", "results"]
    |> Enum.find_value([], fn key ->
      case Map.get(result, key) do
        values when is_list(values) -> values
        _ -> nil
      end
    end)
  end

  defp extract_single_detection_box(obj) do
    label = Map.get(obj, "label") || Map.get(obj, "name") || ""

    extract_minmax_detection_box(obj, label) ||
      extract_array_detection_box(obj, "bbox", label) ||
      extract_array_detection_box(obj, "bounding_box", label)
  end

  defp extract_minmax_detection_box(obj, label) do
    with true <- Enum.all?(~w(x_min x_max y_min y_max), &Map.has_key?(obj, &1)),
         x1 when not is_nil(x1) <- normalize_coordinate(Map.get(obj, "x_min")),
         x2 when not is_nil(x2) <- normalize_coordinate(Map.get(obj, "x_max")),
         y1 when not is_nil(y1) <- normalize_coordinate(Map.get(obj, "y_min")),
         y2 when not is_nil(y2) <- normalize_coordinate(Map.get(obj, "y_max")) do
      %{x1: x1, y1: y1, x2: x2, y2: y2, label: label}
    else
      _ -> nil
    end
  end

  defp extract_array_detection_box(obj, key, label) do
    case Map.get(obj, key) do
      bbox when is_list(bbox) and length(bbox) >= 4 ->
        bbox
        |> Enum.take(4)
        |> normalize_bbox_values()
        |> build_detection_box(label)

      _ ->
        nil
    end
  end

  defp normalize_bbox_values([x1, y1, x2, y2]) do
    [
      normalize_coordinate(x1),
      normalize_coordinate(y1),
      normalize_coordinate(x2),
      normalize_coordinate(y2)
    ]
  end

  defp build_detection_box([x1, y1, x2, y2], label)
       when not is_nil(x1) and not is_nil(y1) and not is_nil(x2) and not is_nil(y2) do
    %{x1: x1, y1: y1, x2: x2, y2: y2, label: label}
  end

  defp build_detection_box(_coords, _label), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4 space-y-4">
      <h2 class="text-lg font-semibold">Moondream AI</h2>

      <.simple_form
        for={%{}}
        as={:moondream}
        phx-change="change"
        phx-submit="submit"
        phx-target={@myself}
        class="pt-2"
      >
        <div class="flex flex-wrap gap-2">
          <label
            :for={func <- function_types()}
            class={[
              "btn rounded-lg",
              if(@function == func, do: "btn-neutral", else: "btn-outline"),
              if(segment_disabled?(func),
                do: "opacity-50 cursor-not-allowed",
                else: "cursor-pointer"
              )
            ]}
            title={if(segment_disabled?(func), do: "Segment function is not available yet", else: "")}
          >
            <input
              type="radio"
              name="moondream[function]"
              value={func}
              class="hidden"
              checked={@function == func}
              disabled={segment_disabled?(func)}
            />
            {String.capitalize(func)}
          </label>
        </div>

        <textarea
          name="moondream[prompt]"
          placeholder="Enter prompt..."
          class="textarea textarea-bordered w-full disabled:border-base-300"
          rows="3"
          disabled={@function == "caption"}
        >{@prompt}</textarea>

        <%= if has_detection_results?(@requests) do %>
          <div class="flex flex-wrap gap-2">
            <button
              :for={tag <- get_detection_tags(@requests)}
              type="button"
              class="btn btn-outline rounded-full"
              phx-click="set-prompt"
              phx-target={@myself}
              phx-value-prompt={tag}
            >
              {tag}
            </button>
          </div>
        <% end %>

        <:actions>
          <div class="flex justify-end">
            <.button>Submit</.button>
          </div>
        </:actions>
      </.simple_form>

      <%= if @requests != [] do %>
        <div class="space-y-2">
          <h3 class="text-md font-semibold">Results</h3>
          <div class="space-y-2">
            <div :for={request <- @requests} class="bg-base-100 rounded-lg p-3 space-y-2">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <.status_badge variant={:neutral}>
                    {String.capitalize(request.function_type)}
                  </.status_badge>
                  <span class="text-sm text-base-content/70">
                    {format_request_datetime(request.inserted_at)}
                  </span>
                </div>
                <%= if request.status == "failed" do %>
                  <.status_badge variant={:error}>
                    {request.status}
                  </.status_badge>
                <% end %>
              </div>

              <%= if request.prompt && request.prompt != "" do %>
                <div class="text-sm">
                  <span class="font-medium">Prompt:</span> {request.prompt}
                </div>
              <% end %>

              <%= if MapSet.member?(@loading_requests, request.id) || request.status == "processing" do %>
                <div class="flex items-center gap-2 text-sm text-base-content/70 py-4">
                  <span class="loading loading-spinner loading-sm"></span> thinking
                </div>
              <% end %>

              <%= if request.status == "completed" && request.result do %>
                {cond do
                  request.function_type == "point" ->
                    case extract_point_coordinates(request.result) do
                      {:single, {x, y}} when is_number(x) and is_number(y) ->
                        render_point_result(assigns, request, [{x, y}])

                      {:multiple, points} when is_list(points) and length(points) > 0 ->
                        render_point_result(assigns, request, points)

                      _ ->
                        render_text_result(assigns, request)
                    end

                  request.function_type == "detect" ->
                    boxes = extract_detection_boxes(request.result)

                    if boxes != [] do
                      render_detect_result(assigns, request, boxes)
                    else
                      render_text_result(assigns, request)
                    end

                  true ->
                    render_text_result(assigns, request)
                end}
              <% end %>

              <%= if request.status == "failed" && request.error_message do %>
                <div class="text-sm text-error space-y-2">
                  <div>
                    <span class="font-medium">Error:</span> {format_error_message(
                      request.error_message
                    )}
                  </div>
                  <div>
                    <.button
                      variant="outline"
                      size="sm"
                      phx-click="retry-request"
                      phx-target={@myself}
                      phx-value-request_id={request.id}
                    >
                      Retry
                    </.button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_text_result(assigns, request) do
    text = format_result(request.result, request.function_type)

    assigns =
      assigns
      |> assign(:text, text)
      |> assign(:request, request)

    ~H"""
    <div class="text-sm bg-base-200 rounded p-2">
      <div class="text-sm whitespace-pre-wrap">
        {@text}
      </div>
    </div>
    """
  end

  defp render_point_result(assigns, request, points) when is_list(points) do
    assigns =
      assigns
      |> assign(:request, request)
      |> assign(:points, points)

    ~H"""
    <div class="space-y-2">
      <div
        class="relative w-full max-w-md"
        id={"moondream-point-#{@request.id}"}
        phx-hook="MoondreamOverlay"
      >
        <.img src={@image.url} alt={@image.note || "Image"} class="w-full h-auto rounded-lg" />
        <%= for {x, y} <- @points do %>
          <span
            class="absolute pointer-events-none z-10"
            data-x={x}
            data-y={y}
            style="transform: translate(-50%, -50%);"
          >
            <span class="relative flex size-2">
              <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-primary opacity-75">
              </span>
              <span class="relative inline-flex size-2 rounded-full bg-primary"></span>
            </span>
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_detect_result(assigns, request, boxes) do
    assigns =
      assigns
      |> assign(:request, request)
      |> assign(:boxes, boxes)

    ~H"""
    <div class="space-y-2">
      <div class="text-sm">
        <span class="font-medium">Detected:</span> {length(@boxes)} object(s)
      </div>
      <div
        class="relative w-full max-w-md"
        id={"moondream-detect-#{@request.id}"}
        phx-hook="MoondreamOverlay"
      >
        <.img src={@image.url} alt={@image.note || "Image"} class="w-full h-auto rounded-lg" />
        <svg
          class="absolute inset-0 pointer-events-none w-full h-full z-10"
          preserveAspectRatio="xMidYMid meet"
          style="position: absolute; top: 0; left: 0;"
        >
          <%= for box <- @boxes do %>
            <rect
              data-x1={box.x1}
              data-y1={box.y1}
              data-x2={box.x2}
              data-y2={box.y2}
              fill="none"
              stroke="var(--color-primary)"
              stroke-width="6"
              opacity="0.9"
            />
            <%= if box.label != "" do %>
              <text
                data-x={box.x1}
                data-y={box.y1}
                font-size="14"
                fill="var(--color-primary)"
                font-weight="bold"
                stroke="#ffffff"
                stroke-width="0.5"
              >
                {box.label}
              </text>
            <% end %>
          <% end %>
        </svg>
      </div>
    </div>
    """
  end
end

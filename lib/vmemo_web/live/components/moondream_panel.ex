defmodule VmemoWeb.LiveComponents.MoondreamPanel do
  use VmemoWeb, :live_component

  alias Vmemo.Photos.PhotoMoondreamRequest
  alias Vmemo.Workers.ProcessMoondreamRequest

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

    if is_segment_disabled?(function) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:prompt, prompt)
       |> assign(:function, function)}
    end
  end

  @impl true
  def handle_event("set_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :prompt, prompt)}
  end

  @impl true
  def handle_event("submit", %{"moondream" => params}, socket) do
    user = socket.assigns.current_user
    photo = socket.assigns.photo
    function = socket.assigns.function
    prompt = Map.get(params, "prompt", "") |> String.trim()
    prompt = if prompt == "", do: socket.assigns.prompt, else: prompt

    if is_segment_disabled?(function) do
      {:noreply, socket}
    else
      case PhotoMoondreamRequest.create(
             %{
               photo_id: photo.id,
               ash_user_id: user.id,
               function_type: function,
               prompt: prompt
             },
             actor: user
           ) do
        {:ok, request} ->
          %{request_id: request.id}
          |> ProcessMoondreamRequest.new()
          |> Oban.insert()

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
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp is_segment_disabled?(function), do: function == "segment"

  defp format_changeset_errors(changeset) do
    case changeset do
      %Ash.Error.Invalid{errors: errors} ->
        errors
        |> Enum.map(fn error ->
          case error do
            %Ash.Error.Changes.Required{field: field} ->
              "#{field} is required"

            %Ash.Error.Changes.InvalidAttribute{field: field, message: message} ->
              "#{field}: #{message}"

            _ ->
              "Validation failed"
          end
        end)
        |> Enum.join("; ")

      _ ->
        "Failed to create request"
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
    objects
    |> Enum.map(fn obj ->
      label = Map.get(obj, "label", "unknown")
      count = Map.get(obj, "count", 1)
      "#{label}: #{count}"
    end)
    |> Enum.join("\n")
  end

  defp format_detection_result(result), do: Jason.encode!(result, pretty: true)

  defp format_point_result(%{"x" => x, "y" => y}) do
    "Point: (#{x}, #{y})"
  end

  defp format_point_result(result), do: Jason.encode!(result, pretty: true)

  defp extract_point_coordinates(result) when is_map(result) do
    cond do
      Map.has_key?(result, "x") and Map.has_key?(result, "y") ->
        x = normalize_coordinate(Map.get(result, "x"))
        y = normalize_coordinate(Map.get(result, "y"))
        if x != nil and y != nil, do: {x, y}, else: nil

      Map.has_key?(result, "points") and is_list(result["points"]) ->
        case result["points"] do
          [point | _] when is_map(point) ->
            x = normalize_coordinate(Map.get(point, "x"))
            y = normalize_coordinate(Map.get(point, "y"))
            if x != nil and y != nil, do: {x, y}, else: nil

          _ ->
            nil
        end

      Map.has_key?(result, "point") and is_map(result["point"]) ->
        point = result["point"]
        x = normalize_coordinate(Map.get(point, "x"))
        y = normalize_coordinate(Map.get(point, "y"))
        if x != nil and y != nil, do: {x, y}, else: nil

      Map.has_key?(result, "coordinates") and is_map(result["coordinates"]) ->
        coords = result["coordinates"]
        x = normalize_coordinate(Map.get(coords, "x"))
        y = normalize_coordinate(Map.get(coords, "y"))
        if x != nil and y != nil, do: {x, y}, else: nil

      true ->
        nil
    end
  end

  defp extract_point_coordinates(_), do: nil

  defp normalize_coordinate(value) when is_number(value), do: value

  defp normalize_coordinate(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp normalize_coordinate(_), do: nil

  defp extract_detection_boxes(result) when is_map(result) do
    objects =
      cond do
        Map.has_key?(result, "data") and is_list(result["data"]) ->
          result["data"]

        Map.has_key?(result, "objects") and is_list(result["objects"]) ->
          result["objects"]

        Map.has_key?(result, "detections") and is_list(result["detections"]) ->
          result["detections"]

        Map.has_key?(result, "results") and is_list(result["results"]) ->
          result["results"]

        true ->
          []
      end

    objects
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn obj ->
      label = Map.get(obj, "label") || Map.get(obj, "name") || ""

      # Support x_min, x_max, y_min, y_max format (normalized coordinates 0-1)
      cond do
        Map.has_key?(obj, "x_min") and Map.has_key?(obj, "x_max") and
          Map.has_key?(obj, "y_min") and Map.has_key?(obj, "y_max") ->
          x_min = normalize_coordinate(Map.get(obj, "x_min"))
          x_max = normalize_coordinate(Map.get(obj, "x_max"))
          y_min = normalize_coordinate(Map.get(obj, "y_min"))
          y_max = normalize_coordinate(Map.get(obj, "y_max"))

          if x_min != nil and x_max != nil and y_min != nil and y_max != nil do
            %{x1: x_min, y1: y_min, x2: x_max, y2: y_max, label: label}
          else
            nil
          end

        # Support bbox array format [x1, y1, x2, y2]
        Map.has_key?(obj, "bbox") ->
          bbox = Map.get(obj, "bbox")

          if is_list(bbox) and length(bbox) >= 4 do
            [x1, y1, x2, y2] = Enum.take(bbox, 4)
            x1 = normalize_coordinate(x1)
            y1 = normalize_coordinate(y1)
            x2 = normalize_coordinate(x2)
            y2 = normalize_coordinate(y2)

            if x1 != nil and y1 != nil and x2 != nil and y2 != nil do
              %{x1: x1, y1: y1, x2: x2, y2: y2, label: label}
            else
              nil
            end
          else
            nil
          end

        Map.has_key?(obj, "bounding_box") ->
          bbox = Map.get(obj, "bounding_box")

          if is_list(bbox) and length(bbox) >= 4 do
            [x1, y1, x2, y2] = Enum.take(bbox, 4)
            x1 = normalize_coordinate(x1)
            y1 = normalize_coordinate(y1)
            x2 = normalize_coordinate(x2)
            y2 = normalize_coordinate(y2)

            if x1 != nil and y1 != nil and x2 != nil and y2 != nil do
              %{x1: x1, y1: y1, x2: x2, y2: y2, label: label}
            else
              nil
            end
          else
            nil
          end

        true ->
          nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp extract_detection_boxes(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4 space-y-4">
      <h2 class="text-lg font-semibold">Moondream AI</h2>

      <.form for={%{}} as={:moondream} phx-change="change" phx-submit="submit" phx-target={@myself}>
        <div class="space-y-4">
          <div class="space-y-2">
            <textarea
              name="moondream[prompt]"
              placeholder="Enter prompt..."
              class="textarea textarea-bordered w-full disabled:border-base-300"
              rows="3"
              disabled={@function == "caption"}
            >{@prompt}</textarea>
          </div>

          <%= if has_detection_results?(@requests) do %>
            <div class="flex flex-wrap gap-2">
              <button
                :for={tag <- get_detection_tags(@requests)}
                type="button"
                class="btn btn-sm btn-outline rounded-full"
                phx-click="set_prompt"
                phx-target={@myself}
                phx-value-prompt={tag}
              >
                {tag}
              </button>
            </div>
          <% end %>

          <div class="flex flex-wrap gap-2">
            <label
              :for={func <- function_types()}
              class={[
                "btn btn-sm rounded-lg",
                if(@function == func, do: "btn-primary", else: "btn-outline"),
                if(is_segment_disabled?(func),
                  do: "opacity-50 cursor-not-allowed",
                  else: "cursor-pointer"
                )
              ]}
              title={
                if(is_segment_disabled?(func), do: "Segment function is not available yet", else: "")
              }
            >
              <input
                type="radio"
                name="moondream[function]"
                value={func}
                class="hidden"
                checked={@function == func}
                disabled={is_segment_disabled?(func)}
              />
              {String.capitalize(func)}
            </label>
          </div>

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary">
              Submit
            </button>
          </div>
        </div>
      </.form>

      <%= if @requests != [] do %>
        <div class="space-y-2">
          <h3 class="text-md font-semibold">Results</h3>
          <div class="space-y-2">
            <div :for={request <- @requests} class="bg-base-100 rounded-lg p-3 space-y-2">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span class="badge badge-outline">
                    {String.capitalize(request.function_type)}
                  </span>
                  <span class="text-sm text-base-content/70">
                    {format_request_datetime(request.inserted_at)}
                  </span>
                </div>
                <%= if request.status == "failed" do %>
                  <span class="badge badge-error">
                    {request.status}
                  </span>
                <% end %>
              </div>

              <%= if request.prompt && request.prompt != "" do %>
                <div class="text-sm">
                  <span class="font-medium">Prompt:</span> {request.prompt}
                </div>
              <% end %>

              <%= if MapSet.member?(@loading_requests, request.id) || request.status == "processing" do %>
                <div class="flex items-center gap-2 text-sm text-base-content/70 py-4">
                  <span class="loading loading-spinner loading-sm"></span> Processing...
                </div>
              <% end %>

              <%= if request.status == "completed" && request.result do %>
                {cond do
                  request.function_type == "point" ->
                    case extract_point_coordinates(request.result) do
                      {x, y} when is_number(x) and is_number(y) ->
                        render_point_result(assigns, request, x, y)

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
                <div class="text-sm text-error">
                  <span class="font-medium">Error:</span> {request.error_message}
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

  defp render_point_result(assigns, request, x, y) do
    assigns =
      assigns
      |> assign(:request, request)
      |> assign(:point_x, x)
      |> assign(:point_y, y)

    ~H"""
    <div class="space-y-2">
      <div
        class="relative w-full max-w-md"
        id={"moondream-point-#{@request.id}"}
        phx-hook="MoondreamOverlay"
      >
        <.img src={@photo.url} alt={@photo.note || "Photo"} class="w-full h-auto rounded-lg" />
        <span
          class="absolute pointer-events-none z-10"
          data-x={@point_x}
          data-y={@point_y}
          style="transform: translate(-50%, -50%);"
        >
          <span class="relative flex size-2">
            <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-primary opacity-75">
            </span>
            <span class="relative inline-flex size-2 rounded-full bg-primary"></span>
          </span>
        </span>
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
        <.img src={@photo.url} alt={@photo.note || "Photo"} class="w-full h-auto rounded-lg" />
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

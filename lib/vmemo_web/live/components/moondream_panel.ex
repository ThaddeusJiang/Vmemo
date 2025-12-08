defmodule VmemoWeb.LiveComponents.MoondreamPanel do
  use VmemoWeb, :live_component

  alias Vmemo.Photos.PhotoMoondreamRequest
  alias Vmemo.Workers.ProcessMoondreamRequest

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
    socket =
      if Map.has_key?(assigns, :photo) do
        assign(socket, :photo, assigns.photo)
      else
        socket
      end

    socket =
      if Map.has_key?(assigns, :current_user) do
        assign(socket, :current_user, assigns.current_user)
      else
        socket
      end

    socket =
      if Map.has_key?(assigns, :requests) do
        assign(socket, :requests, assigns.requests)
      else
        socket
      end

    socket =
      if Map.has_key?(assigns, :loading_requests) do
        assign(socket, :loading_requests, assigns.loading_requests)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("change", %{"moondream" => params}, socket) do
    prompt = Map.get(params, "prompt", socket.assigns.prompt)
    function = Map.get(params, "function", socket.assigns.function)

    {:noreply,
     socket
     |> assign(:prompt, prompt)
     |> assign(:function, function)}
  end

  @impl true
  def handle_event("select_function", %{"function" => function}, socket) do
    {:noreply, assign(socket, :function, function)}
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
        error_msg =
          case changeset.errors do
            [] -> "Failed to create request"
            [{field, {msg, _}} | _] -> "#{field}: #{msg}"
            errors -> "Validation error: #{inspect(errors)}"
          end

        {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
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

  defp is_loading?(loading_requests) do
    MapSet.size(loading_requests) > 0
  end

  defp format_request_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_result(result, _function_type) when is_binary(result), do: result

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4 space-y-4">
      <h2 class="text-lg font-semibold">Moondream AI</h2>

      <.form for={%{}} as={:moondream} phx-change="change" phx-submit="submit" phx-target={@myself}>
        <div class="space-y-4">
          <input type="hidden" name="moondream[function]" value={@function} />

          <div class="space-y-2">
            <textarea
              name="moondream[prompt]"
              placeholder="Enter prompt..."
              class="textarea textarea-bordered w-full"
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
            <button
              :for={func <- ["query", "caption", "point", "detect", "segment"]}
              type="button"
              class={[
                "btn btn-sm rounded-lg",
                if(@function == func, do: "btn-primary", else: "btn-outline")
              ]}
              phx-click="select_function"
              phx-target={@myself}
              phx-value-function={func}
            >
              {String.capitalize(func)}
            </button>
          </div>

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary" disabled={is_loading?(@loading_requests)}>
              <%= if is_loading?(@loading_requests) do %>
                <span class="loading loading-spinner loading-sm"></span> Processing...
              <% else %>
                Submit
              <% end %>
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
                <span class={[
                  "badge",
                  case request.status do
                    "completed" -> "badge-success"
                    "failed" -> "badge-error"
                    "processing" -> "badge-warning"
                    _ -> "badge-info"
                  end
                ]}>
                  {request.status}
                </span>
              </div>

              <%= if request.prompt && request.prompt != "" do %>
                <div class="text-sm">
                  <span class="font-medium">Prompt:</span> {request.prompt}
                </div>
              <% end %>

              <%= if request.status == "completed" && request.result do %>
                <div class="text-sm bg-base-200 rounded p-2">
                  <pre class="whitespace-pre-wrap text-xs">
                    {format_result(request.result, request.function_type)}
                  </pre>
                </div>
              <% end %>

              <%= if request.status == "failed" && request.error_message do %>
                <div class="text-sm text-error">
                  <span class="font-medium">Error:</span> {request.error_message}
                </div>
              <% end %>

              <%= if MapSet.member?(@loading_requests, request.id) do %>
                <div class="flex items-center gap-2 text-sm text-base-content/70">
                  <span class="loading loading-spinner loading-xs"></span> Processing...
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end

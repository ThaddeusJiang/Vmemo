defmodule VmemoWeb.Components.ChatPanel do
  use VmemoWeb, :html

  attr :messages, :list, required: true
  attr :message_form, :any, required: true
  attr :current_user, :map, required: true
  attr :container_id, :string, default: "message-container"
  attr :form_id, :string, default: "message-form"
  attr :empty_title, :string, default: "How can I help you?"
  attr :empty_subtitle, :string, default: "Ask questions about your notes and images."
  attr :placeholder, :string, default: "Ask a question"
  attr :panel_class, :string, default: ""

  def chat_panel(assigns) do
    ~H"""
    <div class={["flex h-full min-h-0 flex-col", @panel_class]}>
      <div class="flex-1 min-h-0 overflow-hidden bg-base-100/55">
        <div
          id={@container_id}
          phx-update="stream"
          class="flex h-full flex-col-reverse overflow-y-auto px-4 py-4"
        >
          <%= if @messages == [] do %>
            <div class="m-auto flex max-w-sm flex-col items-center justify-center text-center text-base-content/75">
              <div class="mb-6 rounded-full border border-base-300 p-4 text-base-content/45">
                <.icon name="hero-chat-bubble-left-right" class="size-7" />
              </div>
              <h2 class="text-3xl font-semibold tracking-tight text-base-content">{@empty_title}</h2>
              <p class="mt-3 text-sm leading-7">{@empty_subtitle}</p>
            </div>
          <% else %>
            <%= for {id, message} <- @messages do %>
              <% images = extract_photos_from_message(message) %>
              <% is_thinking = thinking?(message) %>
              <div
                id={id}
                class={[
                  "chat",
                  message.source == :user && "chat-end",
                  message.source == :agent && "chat-start"
                ]}
              >
                <div :if={message.source == :agent} class="chat-image avatar">
                  <div class="w-10 rounded-full bg-base-300 p-1">
                    <img
                      src={~p"/images/logo.svg"}
                      alt="Vmemo logo"
                      class="h-8 w-8 dark:invert"
                    />
                  </div>
                </div>
                <div :if={message.source == :user} class="chat-image avatar avatar-placeholder">
                  <div class="w-10 rounded-full bg-base-300">
                    <.icon name="hero-user-solid" class="block" />
                  </div>
                </div>
                <div class="chat-bubble max-w-[85%]">
                  <.live_component
                    id={"markdown-#{@container_id}-#{id}"}
                    module={VmemoWeb.LiveComponents.MarkdownContent}
                    text={message.text}
                    current_user={@current_user}
                  />
                  {render_thinking(assigns, is_thinking)}
                  {render_photos(assigns, images)}
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="border-t border-base-300 bg-base-100 p-4">
        <.form
          for={@message_form}
          id={@form_id}
          phx-submit="send-message"
          class="flex items-center gap-3"
        >
          <div class="flex-1 flex items-center [&_.form-control]:flex [&_.form-control]:items-center [&_.form-control>div]:flex [&_.form-control>div]:items-center [&_.form-control>div]:w-full">
            <.input
              field={@message_form[:text]}
              type="text"
              placeholder={@placeholder}
              class="input input-primary w-full mb-0"
              autocomplete="off"
            />
          </div>
          <button type="submit" class="btn btn-primary btn-circle shrink-0" aria-label="Send message">
            <.icon name="hero-arrow-up" class="size-5" />
          </button>
        </.form>
      </div>
    </div>
    """
  end

  defp render_thinking(assigns, true) do
    ~H"""
    <div class="mt-2 flex items-center gap-2 text-sm text-base-content/70">
      <span class="loading loading-spinner loading-sm"></span>
      <span>Thinking...</span>
    </div>
    """
  end

  defp render_thinking(_assigns, false), do: Phoenix.HTML.raw("")

  defp render_photos(assigns, images) do
    if Enum.empty?(images) do
      Phoenix.HTML.raw("")
    else
      assigns = assign(assigns, :images, images)

      ~H"""
      <div class="mt-4 grid grid-cols-2 gap-2 md:grid-cols-3">
        <%= for image <- @images do %>
          <VmemoWeb.LiveComponents.ImageCard.image_card image={image} />
        <% end %>
      </div>
      """
    end
  end

  defp normalize_photo_url(url) when is_binary(url) do
    url_lower = String.downcase(url)

    cond do
      String.starts_with?(url_lower, "https://example.com") ->
        prefix_length = String.length("https://example.com")
        String.slice(url, prefix_length..-1//1)

      String.starts_with?(url_lower, "http://example.com") ->
        prefix_length = String.length("http://example.com")
        String.slice(url, prefix_length..-1//1)

      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
        url

      true ->
        url
    end
  end

  defp normalize_photo_url(url), do: url

  defp extract_photos_from_message(message) do
    if thinking?(message) do
      []
    else
      extract_attachment_images(message) ++ extract_tool_result_images(message)
    end
  end

  defp extract_attachment_images(message) do
    case Map.get(message, :attachments) do
      attachments when is_list(attachments) ->
        attachments
        |> Enum.map(&normalize_photo/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp extract_tool_result_images(message) do
    case Map.get(message, :tool_results) do
      nil ->
        []

      tool_results when is_list(tool_results) ->
        tool_results
        |> Enum.filter(fn result ->
          result_name = get_result_name(result)
          result_name == "search_images" || result_name == :search_images
        end)
        |> Enum.flat_map(&extract_photos_from_tool_result/1)

      _ ->
        []
    end
  end

  defp get_result_name(result) when is_map(result) do
    Map.get(result, "name") || Map.get(result, :name)
  end

  defp get_result_name(_), do: nil

  defp extract_photos_from_tool_result(result) do
    content = Map.get(result, "content") || Map.get(result, :content)

    if is_binary(content) and content != "" do
      case Jason.decode(content) do
        {:ok, decoded} when is_list(decoded) ->
          decoded
          |> Enum.map(&normalize_photo/1)
          |> Enum.reject(&is_nil/1)

        {:ok, decoded} when is_map(decoded) ->
          case Map.get(decoded, "data") || Map.get(decoded, :data) do
            nil ->
              case normalize_photo(decoded) do
                nil -> []
                image -> [image]
              end

            data when is_list(data) ->
              data
              |> Enum.map(&normalize_photo/1)
              |> Enum.reject(&is_nil/1)

            data when is_map(data) ->
              case normalize_photo(data) do
                nil -> []
                image -> [image]
              end

            _ ->
              []
          end

        _ ->
          []
      end
    else
      []
    end
  end

  defp normalize_photo(data) when is_map(data) do
    url = Map.get(data, "url") || Map.get(data, :url)
    id = Map.get(data, "id") || Map.get(data, :id)

    if url do
      %{
        id: id,
        url: normalize_photo_url(url),
        note: Map.get(data, "note") || Map.get(data, :note) || ""
      }
    else
      nil
    end
  end

  defp normalize_photo(data) when is_binary(data) and data != "" do
    %{
      id: nil,
      url: normalize_photo_url(data),
      note: ""
    }
  end

  defp normalize_photo(_), do: nil

  defp thinking?(message) do
    complete = Map.get(message, :complete)
    complete == false || is_nil(complete)
  end
end

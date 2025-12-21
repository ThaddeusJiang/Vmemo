defmodule VmemoWeb.ChatLive do
  use VmemoWeb, :live_view
  # on_mount {VmemoWeb.LiveUserAuth, :live_user_required}
  def render(assigns) do
    ~H"""
    <div class="drawer md:drawer-open bg-base-200 min-h-dvh max-h-dvh">
      <input id="ash-ai-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col">
        <div class="navbar bg-base-300 w-full">
          <div class="flex-none md:hidden">
            <label for="ash-ai-drawer" aria-label="open sidebar" class="btn btn-square btn-ghost">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="inline-block h-6 w-6 stroke-current"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6h16M4 12h16M4 18h16"
                >
                </path>
              </svg>
            </label>
          </div>
          <img
            src="https://github.com/ash-project/ash_ai/blob/main/logos/ash_ai.png?raw=true"
            alt="Logo"
            class="w-12 h-12"
          />
          <div class="mx-2 flex-1 px-2">
            <div :if={@conversation}>
              <.live_component
                id="conversation-title-editor"
                module={VmemoWeb.LiveComponents.ConversationTitleEditor}
                conversation={@conversation}
                current_ash_user={@current_ash_user}
              />
            </div>
          </div>
        </div>
        <div class="flex-1 flex flex-col overflow-y-scroll bg-base-200 max-h-[calc(100dvh-8rem)]">
          <div
            id="message-container"
            phx-update="stream"
            class="flex-1 overflow-y-auto px-4 py-2 flex flex-col-reverse"
          >
            <%= for {id, message} <- @streams.messages do %>
              <% photos = extract_photos_from_message(message) %>
              <% is_thinking = is_thinking?(message) %>
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
                      src="https://github.com/ash-project/ash_ai/blob/main/logos/ash_ai.png?raw=true"
                      alt="Logo"
                    />
                  </div>
                </div>
                <div :if={message.source == :user} class="chat-image avatar avatar-placeholder">
                  <div class="w-10 rounded-full bg-base-300">
                    <.icon name="hero-user-solid" class="block" />
                  </div>
                </div>
                <div class="chat-bubble">
                  {to_markdown(message.text)}
                  {render_thinking(assigns, is_thinking)}
                  {render_photos(assigns, photos)}
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <div class="p-4 border-t h-16">
          <.form
            for={@message_form}
            id="message-form"
            phx-submit="send_message"
            class="flex items-center gap-4"
          >
            <div class="flex-1 flex items-center [&_.form-control]:flex [&_.form-control]:items-center [&_.form-control>div]:flex [&_.form-control>div]:items-center [&_.form-control>div]:w-full">
              <.input
                field={@message_form[:text]}
                type="text"
                phx-mounted={JS.focus()}
                placeholder="Type your message..."
                class="input input-primary w-full mb-0"
                autocomplete="off"
              />
            </div>
            <button type="submit" class="btn btn-primary rounded-full">
              <.icon name="hero-paper-airplane" /> Send
            </button>
          </.form>
        </div>
      </div>

      <div class="drawer-side border-r bg-base-300 min-w-72">
        <div class="py-4 px-6">
          <div class="text-lg mb-4">
            Conversations
          </div>
          <div class="mb-4">
            <.link navigate={~p"/chat"} class="btn btn-primary mb-2">
              <div class="rounded-full bg-primary-content text-primary w-6 h-6 flex items-center justify-center">
                <.icon name="hero-plus" />
              </div>
              <span>New Chat</span>
            </.link>
          </div>
          <ul class="flex flex-col-reverse" phx-update="stream" id="conversations-list">
            <%= for {id, conversation} <- @streams.conversations do %>
              <li id={id}>
                <.link
                  navigate={~p"/chat/#{conversation.id}"}
                  phx-click="select_conversation"
                  phx-value-id={conversation.id}
                  class={"block py-2 px-3 transition border-l-4 pl-2 mb-2 #{if @conversation && @conversation.id == conversation.id, do: "border-primary font-medium", else: "border-transparent"}"}
                >
                  {VmemoWeb.LiveComponents.ConversationTitleEditor.build_title_string(
                    conversation.title
                  )}
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_ash_user

    if connected?(socket) do
      VmemoWeb.Endpoint.subscribe("chat:conversations:#{user.id}")
    end

    socket =
      socket
      |> assign(:page_title, "Chat")
      |> assign(:conversation, nil)
      |> stream(
        :conversations,
        Vmemo.Chat.my_conversations!(actor: user)
      )
      |> assign(:messages, [])
      |> assign_message_form()

    {:ok, socket}
  end

  def handle_params(%{"conversation_id" => conversation_id}, _, socket) do
    user = socket.assigns.current_ash_user

    conversation =
      Vmemo.Chat.get_conversation!(conversation_id, actor: user)

    cond do
      socket.assigns[:conversation] && socket.assigns[:conversation].id == conversation.id ->
        :ok

      socket.assigns[:conversation] ->
        VmemoWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
        VmemoWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")

      true ->
        VmemoWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")
    end

    messages =
      Vmemo.Chat.Message
      |> Ash.Query.for_read(:for_conversation, %{conversation_id: conversation.id})
      |> Ash.Query.select([
        :id,
        :text,
        :source,
        :tool_calls,
        :tool_results,
        :complete,
        :inserted_at
      ])
      |> Ash.read!()

    socket
    |> assign(:conversation, conversation)
    |> stream(:messages, messages)
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_params(_, _, socket) do
    if socket.assigns[:conversation] do
      VmemoWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
    end

    socket
    |> assign(:conversation, nil)
    |> stream(:messages, [])
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_event("send_message", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.message_form.source, params: params) do
      {:ok, message} ->
        if socket.assigns.conversation do
          socket
          |> assign_message_form()
          |> stream_insert(:messages, message, at: 0)
          |> then(&{:noreply, &1})
        else
          {:noreply,
           socket
           |> push_navigate(to: ~p"/chat/#{message.conversation_id}")}
        end

      {:error, form} ->
        {:noreply, assign(socket, :message_form, form)}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:messages:" <> conversation_id,
          payload: message
        },
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      # Merge with existing message data to preserve tool_results and other fields
      # when updating an existing message in the stream
      updated_message =
        case socket.assigns.streams.messages[message.id] do
          nil ->
            # New message, use as is
            message

          existing_message ->
            # Existing message, merge to preserve tool_results and other fields
            # Prefer new values for text and source, but preserve tool_results if new value is nil/empty
            Map.merge(existing_message, message, fn
              :tool_results, existing_tool_results, new_tool_results ->
                # Preserve tool_results if new value is nil or empty
                if is_nil(new_tool_results) ||
                     (is_list(new_tool_results) && Enum.empty?(new_tool_results)) do
                  existing_tool_results
                else
                  new_tool_results
                end

              :tool_calls, existing_tool_calls, new_tool_calls ->
                # Preserve tool_calls if new value is nil or empty
                if is_nil(new_tool_calls) ||
                     (is_list(new_tool_calls) && Enum.empty?(new_tool_calls)) do
                  existing_tool_calls
                else
                  new_tool_calls
                end

              _key, existing_value, new_value ->
                # For other fields, use new value (or existing if new is nil)
                if is_nil(new_value) do
                  existing_value
                else
                  new_value
                end
            end)
        end

      {:noreply, stream_insert(socket, :messages, updated_message, at: 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:conversations:" <> _,
          payload: conversation
        },
        socket
      ) do
    socket =
      if socket.assigns.conversation && socket.assigns.conversation.id == conversation.id do
        assign(socket, :conversation, conversation)
      else
        socket
      end

    {:noreply, stream_insert(socket, :conversations, conversation)}
  end

  def handle_info({:conversation_updated, updated_conversation}, socket) do
    socket =
      if socket.assigns[:conversation] &&
           socket.assigns.conversation.id == updated_conversation.id do
        assign(socket, :conversation, updated_conversation)
      else
        socket
      end

    {:noreply, stream_insert(socket, :conversations, updated_conversation)}
  end

  defp assign_message_form(socket) do
    form =
      if socket.assigns[:conversation] && socket.assigns.conversation do
        AshPhoenix.Form.for_create(
          Vmemo.Chat.Message,
          :create,
          actor: socket.assigns.current_ash_user,
          private_arguments: %{conversation_id: socket.assigns.conversation.id}
        )
        |> to_form()
      else
        AshPhoenix.Form.for_create(
          Vmemo.Chat.Message,
          :create,
          actor: socket.assigns.current_ash_user
        )
        |> to_form()
      end

    assign(
      socket,
      :message_form,
      form
    )
  end

  defp to_markdown(text) do
    # Note that you must pass the "unsafe: true" option to first generate the raw HTML
    # in order to sanitize it. https://hexdocs.pm/mdex/MDEx.html#module-sanitize
    MDEx.to_html(text,
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        github_pre_lang: true,
        unsafe: true
      ],
      sanitize: MDEx.Document.default_sanitize_options()
    )
    |> case do
      {:ok, html} ->
        html
        |> Phoenix.HTML.raw()

      {:error, _} ->
        text
    end
  end

  defp render_thinking(assigns, true) do
    ~H"""
    <div class="mt-2 flex items-center gap-2 text-sm text-base-content/70">
      <span class="loading loading-spinner loading-sm"></span>
      <span>Thinking...</span>
    </div>
    """
  end

  defp render_thinking(assigns, false) do
    ~H"""
    """
  end

  defp render_photos(assigns, photos) do
    if Enum.empty?(photos) do
      Phoenix.HTML.raw("")
    else
      assigns = assign(assigns, :photos, photos)

      ~H"""
      <div class="mt-4 grid grid-cols-2 md:grid-cols-3 gap-2">
        <%= for photo <- @photos do %>
          <div class="relative">
            <.link navigate={~p"/photos/#{photo.id}"} class="block">
              <.img
                src={normalize_photo_url(photo.url)}
                alt={photo.note || "Photo"}
                class="w-full h-auto rounded-lg"
              />
            </.link>
          </div>
        <% end %>
      </div>
      """
    end
  end

  defp normalize_photo_url(url) when is_binary(url) do
    url_lower = String.downcase(url)

    cond do
      # If URL is absolute with wrong domain (example.com), convert to relative path
      # Handle case-insensitive matching
      String.starts_with?(url_lower, "https://example.com") ->
        # Extract path after domain (case-insensitive)
        prefix_length = String.length("https://example.com")
        String.slice(url, prefix_length..-1//1)

      String.starts_with?(url_lower, "http://example.com") ->
        prefix_length = String.length("http://example.com")
        String.slice(url, prefix_length..-1//1)

      # If URL is absolute with correct domain, keep as is
      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
        url

      # Relative path, keep as is (browser will use current domain)
      true ->
        url
    end
  end

  defp normalize_photo_url(url), do: url

  defp extract_photos_from_message(message) do
    # If message is not complete (still thinking), don't show photos
    if is_thinking?(message) do
      []
    else
      case Map.get(message, :tool_results) do
        nil ->
          []

        tool_results when is_list(tool_results) ->
          tool_results
          |> Enum.filter(fn result ->
            result_name = get_result_name(result)
            result_name == "search_photos" || result_name == :search_photos
          end)
          |> Enum.flat_map(fn result ->
            extract_photos_from_tool_result(result)
          end)

        _ ->
          []
      end
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
          # Handle case where content is a single object or wrapped in a structure
          case Map.get(decoded, "data") || Map.get(decoded, :data) do
            nil ->
              case normalize_photo(decoded) do
                nil -> []
                photo -> [photo]
              end

            data when is_list(data) ->
              data
              |> Enum.map(&normalize_photo/1)
              |> Enum.reject(&is_nil/1)

            data when is_map(data) ->
              case normalize_photo(data) do
                nil -> []
                photo -> [photo]
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
    id = Map.get(data, "id") || Map.get(data, :id)
    url = Map.get(data, "url") || Map.get(data, :url)

    if id && url do
      %{
        id: id,
        url: normalize_photo_url(url),
        note: Map.get(data, "note") || Map.get(data, :note) || ""
      }
    else
      nil
    end
  end

  defp normalize_photo(_), do: nil

  defp is_thinking?(message) do
    # Message is thinking if it's not complete yet
    complete = Map.get(message, :complete)
    complete == false || is_nil(complete)
  end
end

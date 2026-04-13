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
            src={~p"/images/logo.svg"}
            alt="Vmemo logo"
            class="w-12 h-12"
          />
          <div class="mx-2 flex-1 px-2">
            <div :if={@conversation}>
              <.live_component
                id="conversation-title-editor"
                module={VmemoWeb.LiveComponents.ConversationTitleEditor}
                conversation={@conversation}
                current_user={@current_user}
              />
            </div>
          </div>
          <div :if={@conversation} class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-square">
              <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow border border-base-300"
            >
              <li>
                <button
                  type="button"
                  phx-click="archive-conversation"
                  phx-value-id={@conversation.id}
                  class="text-base-content"
                >
                  <.icon name="hero-archive-box" class="h-4 w-4" /> Archive
                </button>
              </li>
              <li>
                <button
                  type="button"
                  phx-click="delete-conversation"
                  phx-value-id={@conversation.id}
                  class="text-error"
                >
                  <.icon name="hero-trash" class="h-4 w-4" /> Delete
                </button>
              </li>
            </ul>
          </div>
        </div>
        <div class="flex-1 flex flex-col overflow-y-scroll bg-base-200 max-h-[calc(100dvh-8rem)]">
          <div
            id="message-container"
            phx-update="stream"
            class="flex-1 overflow-y-auto px-4 py-2 flex flex-col-reverse"
          >
            <%= for {id, message} <- @streams.messages do %>
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
                      class="w-8 h-8"
                    />
                  </div>
                </div>
                <div :if={message.source == :user} class="chat-image avatar avatar-placeholder">
                  <div class="w-10 rounded-full bg-base-300">
                    <.icon name="hero-user-solid" class="block" />
                  </div>
                </div>
                <div class="chat-bubble">
                  <.live_component
                    id={"markdown-#{id}"}
                    module={VmemoWeb.LiveComponents.MarkdownContent}
                    text={message.text}
                    current_user={@current_user}
                  />
                  {render_thinking(assigns, is_thinking)}
                  {render_photos(assigns, images)}
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <div class="p-4 border-t h-16">
          <.form
            for={@message_form}
            id="message-form"
            phx-submit="send-message"
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
                  phx-click="select-conversation"
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
    user = socket.assigns.current_user

    if connected?(socket) do
      VmemoWeb.Endpoint.subscribe("chat:conversations:#{user.id}")
    end

    socket =
      socket
      |> assign(:page_title, "Chat")
      |> assign(:conversation, nil)
      |> stream_configure(:conversations, dom_id: &"conversation-#{&1.id}")
      |> stream(
        :conversations,
        Vmemo.Chat.my_conversations!(actor: user)
      )
      |> assign(:messages, [])
      |> assign_message_form()

    {:ok, socket}
  end

  def handle_params(%{"conversation_id" => conversation_id}, _, socket) do
    user = socket.assigns.current_user

    case Vmemo.Chat.get_conversation(conversation_id, actor: user) do
      {:ok, conversation} ->
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

      {:error, _} ->
        # Conversation not found (deleted or doesn't exist), redirect to chat list
        {:noreply, push_navigate(socket, to: ~p"/chat")}
    end
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

  def handle_event("send-message", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.message_form.source, params: params) do
      {:ok, message} ->
        if socket.assigns.conversation do
          socket
          |> assign_message_form()
          |> stream_insert(:messages, message, at: 0)
          |> push_event("reset_form", %{form_id: "message-form"})
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

  def handle_event("archive-conversation", %{"id" => conversation_id}, socket) do
    user = socket.assigns.current_user

    case Vmemo.Chat.get_conversation(conversation_id, actor: user) do
      {:ok, conversation} ->
        case Vmemo.Chat.archive_conversation(conversation, actor: user) do
          {:ok, _archived_conversation} ->
            # Remove from stream and navigate away if it's the current conversation
            socket =
              socket
              |> put_flash(:info, "Conversation archived")
              |> stream_delete(:conversations, conversation)
              |> then(fn s ->
                if s.assigns[:conversation] && s.assigns.conversation.id == conversation_id do
                  push_navigate(s, to: ~p"/chat")
                else
                  s
                end
              end)

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to archive conversation")}
        end

      {:error, _} ->
        # Conversation not found, try to find it in stream and remove
        conversation_in_stream =
          Enum.find(socket.assigns.streams.conversations.inserts, fn {_id, conv} ->
            conv.id == conversation_id
          end)

        socket =
          if conversation_in_stream do
            {_id, conv} = conversation_in_stream
            stream_delete(socket, :conversations, conv)
          else
            socket
          end

        {:noreply, socket}
    end
  end

  def handle_event("delete-conversation", %{"id" => conversation_id}, socket) do
    user = socket.assigns.current_user

    case Vmemo.Chat.get_conversation(conversation_id, actor: user) do
      {:ok, conversation} ->
        case Vmemo.Chat.delete_conversation(conversation, actor: user) do
          :ok ->
            # Remove from stream and navigate away if it's the current conversation
            socket =
              socket
              |> put_flash(:info, "Conversation deleted")
              |> stream_delete(:conversations, conversation)
              |> then(fn s ->
                if s.assigns[:conversation] && s.assigns.conversation.id == conversation_id do
                  push_navigate(s, to: ~p"/chat")
                else
                  s
                end
              end)

            {:noreply, socket}

          {:ok, _} ->
            # Same handling for {:ok, destroyed} case
            socket =
              socket
              |> put_flash(:info, "Conversation deleted")
              |> stream_delete(:conversations, conversation)
              |> then(fn s ->
                if s.assigns[:conversation] && s.assigns.conversation.id == conversation_id do
                  push_navigate(s, to: ~p"/chat")
                else
                  s
                end
              end)

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to delete conversation")}
        end

      {:error, _} ->
        # Conversation not found, try to find it in stream and remove
        conversation_in_stream =
          Enum.find(socket.assigns.streams.conversations.inserts, fn {_id, conv} ->
            conv.id == conversation_id
          end)

        socket =
          if conversation_in_stream do
            {_id, conv} = conversation_in_stream
            stream_delete(socket, :conversations, conv)
          else
            socket
          end

        {:noreply, socket}
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
      existing_message =
        socket.assigns.streams.messages.inserts
        |> Enum.find_value(fn {_id, msg} ->
          if msg.id == message.id, do: msg
        end)

      updated_message =
        case existing_message do
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
          actor: socket.assigns.current_user,
          private_arguments: %{conversation_id: socket.assigns.conversation.id}
        )
        |> to_form()
      else
        AshPhoenix.Form.for_create(
          Vmemo.Chat.Message,
          :create,
          actor: socket.assigns.current_user
        )
        |> to_form()
      end

    assign(
      socket,
      :message_form,
      form
    )
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

  defp render_photos(assigns, images) do
    if Enum.empty?(images) do
      Phoenix.HTML.raw("")
    else
      assigns = assign(assigns, :images, images)

      ~H"""
      <div class="mt-4 grid grid-cols-2 md:grid-cols-3 gap-2">
        <%= for {image, index} <- Enum.with_index(@images) do %>
          <VmemoWeb.LiveComponents.ImageCard.image_card image={image} />
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
    # If message is not complete (still thinking), don't show images
    if thinking?(message) do
      []
    else
      case Map.get(message, :tool_results) do
        nil ->
          []

        tool_results when is_list(tool_results) ->
          tool_results
          |> Enum.filter(fn result ->
            result_name = get_result_name(result)
            result_name == "search_images" || result_name == :search_images
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
    # Message is thinking if it's not complete yet
    complete = Map.get(message, :complete)
    complete == false || is_nil(complete)
  end
end

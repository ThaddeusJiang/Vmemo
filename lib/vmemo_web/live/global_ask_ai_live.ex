defmodule VmemoWeb.GlobalAskAiLive do
  use VmemoWeb, :live_view

  alias Vmemo.Account
  alias Vmemo.Chat
  alias Vmemo.Chat.Commands
  alias Vmemo.Memo.Image
  alias VmemoWeb.LiveComponents.ChatPanel
  alias VmemoWeb.LiveComponents.ConversationTitleEditor

  @impl true
  def mount(_params, session, socket) do
    user = Account.get_user!(session["user_id"])
    filter_image_id = session["image_id"]
    conversation = initial_conversation(user, filter_image_id)
    conversations = Chat.my_conversations!(actor: user)

    if connected?(socket) do
      VmemoWeb.Endpoint.subscribe("chat:conversations:#{user.id}")

      if conversation do
        VmemoWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")
      end
    end

    socket =
      socket
      |> assign(:current_user, user)
      |> assign(:hide_global_ask_ai, true)
      |> assign(:filter_image_id, filter_image_id)
      |> assign(:drawer_toggle_id, "global-ask-ai-toggle-#{socket.id}")
      |> assign(:drawer_form_id, "global-ask-ai-form-#{socket.id}")
      |> assign(:drawer_message_container_id, "global-ask-ai-messages-#{socket.id}")
      |> assign(:conversation, conversation)
      |> assign_conversation_catalog(conversations, user)
      |> stream_configure(:messages, dom_id: &"drawer-message-#{&1.id}")
      |> stream(:messages, load_messages(conversation, user))
      |> assign_message_form()

    {:ok, socket, layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="global-ask-ai-root"
      phx-hook="AskAiUrlSync"
      class="fixed inset-0 z-[100] pointer-events-none"
    >
      <input id={@drawer_toggle_id} type="checkbox" class="peer hidden" phx-update="ignore" />

      <label
        for={@drawer_toggle_id}
        id="global-ask-ai-launch"
        class="pointer-events-auto fixed bottom-6 right-4 btn btn-primary rounded-full shadow-lg transition-opacity peer-checked:pointer-events-none peer-checked:opacity-0"
      >
        <.icon name="hero-chat-bubble-left-right" class="size-5" />
        <span>Ask AI</span>
      </label>

      <label
        for={@drawer_toggle_id}
        class="pointer-events-auto absolute inset-0 hidden bg-black/35 peer-checked:block"
        aria-label="Close Ask AI drawer overlay"
      >
      </label>

      <aside
        id="global-ask-ai-drawer"
        phx-hook="DrawerResize"
        data-min-width="420"
        data-max-width="960"
        data-default-width="640"
        data-storage-key="global-ask-ai-drawer-width"
        class="global-ask-ai-drawer pointer-events-auto fixed right-0 top-0 z-[101] flex h-full translate-x-full flex-col border-l border-base-300 bg-base-100 shadow-2xl transition-transform duration-200 ease-out peer-checked:translate-x-0"
      >
        <div
          data-role="drawer-resize-handle"
          class="absolute left-0 top-0 hidden h-full w-3 -translate-x-1/2 cursor-col-resize touch-none lg:block"
          aria-hidden="true"
        >
          <div class="mx-auto h-full w-px bg-base-300/80"></div>
        </div>

        <div class="flex h-16 items-center justify-between border-b border-base-300 px-4">
          <div class="w-3/4 min-w-0 flex items-center gap-2">
            <img
              :if={
                @conversation && @conversation.image_id &&
                  Map.has_key?(@conversation_image_thumbnails, @conversation.image_id)
              }
              src={Map.get(@conversation_image_thumbnails, @conversation.image_id)}
              alt="Conversation image"
              class="size-8 rounded-md object-cover border border-base-300/70"
            />
            <div class="min-w-0 flex-1 max-w-sm">
              <.live_component
                :if={@conversation}
                id="global-conversation-title-editor"
                module={ConversationTitleEditor}
                conversation={@conversation}
                current_user={@current_user}
                display_class="w-full"
              />
              <div :if={!@conversation} class="text-base font-semibold text-base-content">
                Ash AI
              </div>
            </div>
          </div>
          <div class="shrink-0 flex items-center gap-1">
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                class="btn btn-ghost btn-sm btn-square"
                aria-label="Open chat menu"
              >
                <.icon name="hero-ellipsis-horizontal" class="size-5" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content elevated-popover menu bg-base-100 rounded-box z-[110] mt-2 max-h-80 w-72 overflow-y-auto p-2 shadow-lg"
              >
                <li>
                  <button type="button" phx-click="new-chat">
                    <.icon name="hero-plus" class="size-4" />
                    <span>New chat</span>
                  </button>
                </li>
                <li class="menu-title px-2 py-1 text-xs text-base-content/60">
                  <span>Chats</span>
                </li>
                <%= for conversation <- @conversations do %>
                  <li>
                    <button
                      type="button"
                      phx-click="select-conversation"
                      phx-value-id={conversation.id}
                      class={[
                        "flex items-center gap-2",
                        if(@conversation && @conversation.id == conversation.id, do: "active")
                      ]}
                    >
                      <img
                        :if={
                          conversation.image_id &&
                            Map.has_key?(@conversation_image_thumbnails, conversation.image_id)
                        }
                        src={Map.get(@conversation_image_thumbnails, conversation.image_id)}
                        alt="Conversation image"
                        class="size-6 rounded object-cover border border-base-300/70 shrink-0"
                      />
                      <span class="truncate">
                        {conversation_title(conversation)}
                      </span>
                    </button>
                  </li>
                <% end %>
              </ul>
            </div>
            <label
              for={@drawer_toggle_id}
              id="global-ask-ai-close"
              class="btn btn-ghost btn-sm btn-square"
              aria-label="Close Ask AI drawer"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </label>
          </div>
        </div>

        <ChatPanel.chat_panel
          messages={@streams.messages}
          message_form={@message_form}
          current_user={@current_user}
          form_id={@drawer_form_id}
          container_id={@drawer_message_container_id}
          placeholder="Ask a question"
          empty_title="How can I help you?"
          empty_subtitle="Ask questions about your notes and images."
          panel_class="min-h-0 flex-1"
        />
      </aside>
    </div>
    """
  end

  @impl true
  def handle_event("send-message", %{"form" => params}, socket) do
    text = Map.get(params, "text", "")

    case Commands.parse(text) do
      {:ok, command} ->
        handle_chat_command(command, socket)

      :no_command ->
        case AshPhoenix.Form.submit(socket.assigns.message_form.source, params: params) do
          {:ok, message} ->
            conversation =
              socket.assigns.conversation ||
                Chat.get_conversation!(message.conversation_id,
                  actor: socket.assigns.current_user
                )

            {:noreply,
             socket
             |> maybe_subscribe_to_conversation(conversation)
             |> assign(:conversation, conversation)
             |> sync_url_with_conversation(conversation)
             |> assign_message_form()
             |> stream_insert(:messages, message, at: 0)
             |> push_event("reset_form", %{form_id: socket.assigns.drawer_form_id})}

          {:error, form} ->
            {:noreply, assign(socket, :message_form, form)}
        end
    end
  end

  def handle_event("new-chat", _, socket) do
    user = socket.assigns.current_user

    conversation_result =
      if socket.assigns.filter_image_id do
        Chat.create_image_scoped_conversation(
          %{title: nil, image_id: socket.assigns.filter_image_id},
          actor: user
        )
      else
        Chat.create_conversation(%{title: nil}, actor: user)
      end

    case conversation_result do
      {:ok, conversation} ->
        {:noreply, switch_conversation(socket, conversation, actor: user)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create conversation")}
    end
  end

  def handle_event("select-conversation", %{"id" => conversation_id}, socket) do
    user = socket.assigns.current_user

    case Chat.get_conversation(conversation_id, actor: user) do
      {:ok, conversation} ->
        {:noreply, switch_conversation(socket, conversation, actor: user)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Conversation not found")}
    end
  end

  def handle_event("init-conversation-from-url", %{"conversation_id" => conversation_id}, socket) do
    user = socket.assigns.current_user

    case Chat.get_conversation(conversation_id, actor: user) do
      {:ok, conversation} ->
        {:noreply, switch_conversation(socket, conversation, actor: user)}

      {:error, _} ->
        {:noreply, sync_url_with_conversation(socket, socket.assigns.conversation)}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:messages:" <> conversation_id,
          payload: message
        },
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      updated_message = merge_message(socket.assigns.streams.messages.inserts, message)
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
    conversations = Chat.my_conversations!(actor: socket.assigns.current_user)

    socket =
      socket
      |> assign_conversation_catalog(conversations, socket.assigns.current_user)
      |> then(fn s ->
        if s.assigns.conversation && s.assigns.conversation.id == conversation.id do
          assign(s, :conversation, conversation)
        else
          s
        end
      end)

    {:noreply, socket}
  end

  def handle_info({:conversation_updated, updated_conversation}, socket) do
    user = socket.assigns.current_user
    conversations = Chat.my_conversations!(actor: user)

    socket =
      socket
      |> assign(:conversation, updated_conversation)
      |> assign_conversation_catalog(conversations, user)

    {:noreply, socket}
  end

  defp assign_message_form(socket) do
    private_arguments =
      cond do
        socket.assigns.conversation ->
          %{conversation_id: socket.assigns.conversation.id}

        is_binary(socket.assigns.filter_image_id) ->
          %{image_id: socket.assigns.filter_image_id}

        true ->
          %{}
      end

    form =
      AshPhoenix.Form.for_create(Vmemo.Chat.Message, :create,
        actor: socket.assigns.current_user,
        private_arguments: private_arguments
      )
      |> to_form()

    assign(socket, :message_form, form)
  end

  defp initial_conversation(user, nil) do
    Chat.my_conversations!(actor: user)
    |> Enum.find(&(&1.kind == "global"))
    |> case do
      nil ->
        case Chat.create_conversation(%{title: nil}, actor: user) do
          {:ok, conversation} -> conversation
          _ -> nil
        end

      conversation ->
        conversation
    end
  end

  defp initial_conversation(user, image_id) do
    Chat.list_conversations_by_initial_image(user, image_id)
    |> List.first()
    |> case do
      nil ->
        case Chat.create_image_scoped_conversation(%{title: nil, image_id: image_id},
               actor: user
             ) do
          {:ok, conversation} -> conversation
          _ -> nil
        end

      conversation ->
        conversation
    end
  end

  defp load_messages(nil, _user), do: []

  defp load_messages(conversation, user) do
    Vmemo.Chat.Message
    |> Ash.Query.for_read(:for_conversation, %{conversation_id: conversation.id})
    |> Ash.Query.select([
      :id,
      :text,
      :source,
      :attachments,
      :provider,
      :tool_name,
      :tool_calls,
      :tool_results,
      :complete,
      :inserted_at
    ])
    |> Ash.read!(actor: user)
  end

  defp maybe_subscribe_to_conversation(socket, nil), do: socket

  defp maybe_subscribe_to_conversation(socket, conversation) do
    if connected?(socket) do
      VmemoWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")
    end

    socket
  end

  defp maybe_unsubscribe_from_conversation(socket) do
    if connected?(socket) && socket.assigns.conversation do
      VmemoWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
    end

    socket
  end

  defp switch_conversation(socket, conversation, opts) do
    actor = Keyword.fetch!(opts, :actor)

    socket
    |> maybe_unsubscribe_from_conversation()
    |> maybe_subscribe_to_conversation(conversation)
    |> assign(:conversation, conversation)
    |> assign_conversation_catalog(Chat.my_conversations!(actor: actor), actor)
    |> stream(:messages, load_messages(conversation, actor), reset: true)
    |> assign_message_form()
    |> sync_url_with_conversation(conversation)
  end

  defp assign_conversation_catalog(socket, conversations, user) do
    assign(socket,
      conversations: conversations,
      conversation_image_thumbnails: load_image_thumbnails(conversations, user)
    )
  end

  defp load_image_thumbnails(conversations, user) do
    image_ids =
      conversations
      |> Enum.map(& &1.image_id)
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    if image_ids == [] do
      %{}
    else
      Enum.reduce(image_ids, %{}, fn image_id, acc ->
        case Ash.get(Image, image_id, actor: user) do
          {:ok, image} -> Map.put(acc, image.id, image.url)
          _ -> acc
        end
      end)
    end
  end

  defp sync_url_with_conversation(socket, nil) do
    push_event(socket, "ask_ai_sync_url", %{conversation_id: nil})
  end

  defp sync_url_with_conversation(socket, conversation) do
    push_event(socket, "ask_ai_sync_url", %{conversation_id: conversation.id})
  end

  defp merge_message(existing_messages, message) do
    existing_message =
      existing_messages
      |> Enum.find_value(fn {_id, msg} -> if msg.id == message.id, do: msg end)

    case existing_message do
      nil ->
        message

      existing_message ->
        Map.merge(existing_message, message, fn
          :tool_results, existing_tool_results, new_tool_results ->
            if is_nil(new_tool_results) ||
                 (is_list(new_tool_results) && Enum.empty?(new_tool_results)) do
              existing_tool_results
            else
              new_tool_results
            end

          :tool_calls, existing_tool_calls, new_tool_calls ->
            if is_nil(new_tool_calls) || (is_list(new_tool_calls) && Enum.empty?(new_tool_calls)) do
              existing_tool_calls
            else
              new_tool_calls
            end

          _key, existing_value, new_value ->
            if is_nil(new_value), do: existing_value, else: new_value
        end)
    end
  end

  defp handle_chat_command(:clear, socket) do
    user = socket.assigns.current_user
    conversation = socket.assigns.conversation
    now = DateTime.utc_now()

    with {:ok, updated} <- Chat.clear_context(conversation, now, actor: user),
         {:ok, feedback} <-
           Chat.create_system_message(
             %{conversation_id: conversation.id, text: "Context cleared. History is preserved."},
             actor: user
           ) do
      {:noreply,
       socket
       |> assign(:conversation, updated)
       |> stream_insert(:messages, feedback, at: 0)
       |> push_event("reset_form", %{form_id: socket.assigns.drawer_form_id})}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to clear context")}
    end
  end

  defp handle_chat_command(:compact, socket) do
    user = socket.assigns.current_user
    conversation = socket.assigns.conversation
    now = DateTime.utc_now()

    messages =
      Vmemo.Chat.Message
      |> Ash.Query.for_read(:for_conversation, %{conversation_id: conversation.id})
      |> Ash.Query.select([:source, :text])
      |> Ash.read!(actor: user)
      |> Enum.reverse()

    summary = Commands.compact_summary(messages)

    with {:ok, updated} <- Chat.compact_context(conversation, now, summary, actor: user),
         {:ok, feedback} <-
           Chat.create_system_message(
             %{
               conversation_id: conversation.id,
               text: "Context compacted. History is preserved."
             },
             actor: user
           ) do
      {:noreply,
       socket
       |> assign(:conversation, updated)
       |> stream_insert(:messages, feedback, at: 0)
       |> push_event("reset_form", %{form_id: socket.assigns.drawer_form_id})}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to compact context")}
    end
  end

  defp conversation_title(nil), do: "Ash AI"

  defp conversation_title(conversation) do
    ConversationTitleEditor.chat_title(conversation.title)
  end
end

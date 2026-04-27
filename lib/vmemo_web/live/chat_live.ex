defmodule VmemoWeb.ChatLive do
  use VmemoWeb, :live_view
  alias Vmemo.Chat.Commands
  alias VmemoWeb.Components.ChatPanel
  # on_mount {VmemoWeb.LiveUserAuth, :live_user_required}
  def render(assigns) do
    ~H"""
    <div class="drawer md:drawer-open min-h-dvh max-h-dvh bg-[radial-gradient(circle_at_top_left,_color-mix(in_oklch,var(--color-primary)_9%,transparent)_0%,transparent_35%)]">
      <input id="ash-ai-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col">
        <div class="navbar bg-base-100/80 border-b border-base-300/80 backdrop-blur w-full">
          <div class="flex-none md:hidden">
            <label for="ash-ai-drawer" aria-label="open sidebar" class="btn btn-square btn-ghost">
              <.icon name="hero-bars-3" class="inline-block h-6 w-6 stroke-current" />
            </label>
          </div>
          <img
            src={~p"/images/logo.svg"}
            alt="Vmemo logo"
            class="w-12 h-12 dark:invert"
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
              class="dropdown-content elevated-popover menu bg-base-100 rounded-box z-[90] w-52 p-2"
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
        <ChatPanel.chat_panel
          messages={@streams.messages}
          message_form={@message_form}
          current_user={@current_user}
          form_id="message-form"
          container_id="message-container"
          placeholder="Type your message..."
          empty_title="How can I help you?"
          empty_subtitle="Ask questions about your notes and images."
          panel_class="flex-1 min-h-0"
        />
      </div>

      <div class="drawer-side border-r border-base-300/80 bg-base-100/90 min-w-72">
        <div class="py-4 px-6">
          <div class="text-lg mb-4">
            Conversations
          </div>
          <div class="mb-4">
            <button type="button" phx-click="new-chat" class="btn btn-primary mb-2">
              <div class="rounded-full bg-primary-content text-primary w-6 h-6 flex items-center justify-center">
                <.icon name="hero-plus" />
              </div>
              <span>New Chat</span>
            </button>
            <div :if={@filter_image_id} class="text-xs text-base-content/70">
              Filtered by image: {@filter_image_id}
            </div>
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
                  {VmemoWeb.LiveComponents.ConversationTitleEditor.chat_title(conversation.title)}
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
      |> assign(:hide_global_ask_ai, true)
      |> assign(:conversation, nil)
      |> assign(:filter_image_id, nil)
      |> stream_configure(:conversations, dom_id: &"conversation-#{&1.id}")
      |> stream(
        :conversations,
        Vmemo.Chat.my_conversations!(actor: user)
      )
      |> assign(:messages, [])
      |> assign_message_form()

    {:ok, socket}
  end

  def handle_params(%{"conversation_id" => conversation_id} = params, _, socket) do
    user = socket.assigns.current_user
    filter_image_id = Map.get(params, "image_id", socket.assigns[:filter_image_id])

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
            :attachments,
            :provider,
            :tool_name,
            :tool_calls,
            :tool_results,
            :complete,
            :inserted_at
          ])
          |> Ash.read!()

        socket
        |> assign(:filter_image_id, filter_image_id)
        |> assign(:conversation, conversation)
        |> stream(:conversations, list_conversations(user, filter_image_id), reset: true)
        |> stream(:messages, messages)
        |> assign_message_form()
        |> then(&{:noreply, &1})

      {:error, _} ->
        # Conversation not found (deleted or doesn't exist), redirect to chat list
        {:noreply, push_navigate(socket, to: ~p"/chat")}
    end
  end

  def handle_params(params, _, socket) do
    user = socket.assigns.current_user
    filter_image_id = Map.get(params, "image_id")

    if socket.assigns[:conversation] do
      VmemoWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
    end

    socket
    |> assign(:filter_image_id, filter_image_id)
    |> assign(:conversation, nil)
    |> stream(:conversations, list_conversations(user, filter_image_id), reset: true)
    |> stream(:messages, [])
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_event("send-message", %{"form" => params}, socket) do
    text = Map.get(params, "text", "")

    case Commands.parse(text) do
      {:ok, command} ->
        handle_chat_command(command, socket)

      :no_command ->
        case AshPhoenix.Form.submit(socket.assigns.message_form.source, params: params) do
          {:ok, message} ->
            handle_submitted_message(socket, message)

          {:error, form} ->
            {:noreply, assign(socket, :message_form, form)}
        end
    end
  end

  def handle_event("new-chat", _, socket) do
    user = socket.assigns.current_user

    conversation_result =
      if socket.assigns.filter_image_id do
        Vmemo.Chat.create_image_scoped_conversation(
          %{title: nil, image_id: socket.assigns.filter_image_id},
          actor: user
        )
      else
        Vmemo.Chat.create_conversation(%{title: nil}, actor: user)
      end

    case conversation_result do
      {:ok, conversation} ->
        {:noreply, push_navigate(socket, to: ~p"/chat/#{conversation.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create conversation")}
    end
  end

  def handle_event("archive-conversation", %{"id" => conversation_id}, socket) do
    user = socket.assigns.current_user

    case Vmemo.Chat.get_conversation(conversation_id, actor: user) do
      {:ok, conversation} ->
        handle_archive_conversation(socket, user, conversation, conversation_id)

      {:error, _} ->
        {:noreply, remove_conversation_from_stream(socket, conversation_id)}
    end
  end

  def handle_event("delete-conversation", %{"id" => conversation_id}, socket) do
    user = socket.assigns.current_user

    case Vmemo.Chat.get_conversation(conversation_id, actor: user) do
      {:ok, conversation} ->
        handle_delete_conversation(socket, user, conversation, conversation_id)

      {:error, _} ->
        {:noreply, remove_conversation_from_stream(socket, conversation_id)}
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
    matches_filter? =
      is_nil(socket.assigns.filter_image_id) ||
        socket.assigns.filter_image_id == conversation.image_id

    socket =
      if socket.assigns.conversation && socket.assigns.conversation.id == conversation.id &&
           matches_filter? do
        assign(socket, :conversation, conversation)
      else
        socket
      end

    socket =
      if matches_filter? do
        stream_insert(socket, :conversations, conversation)
      else
        stream_delete(socket, :conversations, conversation)
      end

    {:noreply, socket}
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
        private_arguments =
          if is_binary(socket.assigns.filter_image_id) do
            %{image_id: socket.assigns.filter_image_id}
          else
            %{}
          end

        AshPhoenix.Form.for_create(Vmemo.Chat.Message, :create,
          actor: socket.assigns.current_user,
          private_arguments: private_arguments
        )
        |> to_form()
      end

    assign(
      socket,
      :message_form,
      form
    )
  end

  defp list_conversations(user, nil), do: Vmemo.Chat.my_conversations!(actor: user)

  defp list_conversations(user, image_id) when is_binary(image_id) do
    Vmemo.Chat.list_conversations_by_initial_image(user, image_id)
  end

  defp handle_archive_conversation(socket, user, conversation, conversation_id) do
    case Vmemo.Chat.archive_conversation(conversation, actor: user) do
      {:ok, _archived_conversation} ->
        {:noreply,
         apply_conversation_removal(
           socket,
           conversation,
           conversation_id,
           "Conversation archived"
         )}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to archive conversation")}
    end
  end

  defp handle_delete_conversation(socket, user, conversation, conversation_id) do
    case Vmemo.Chat.delete_conversation(conversation, actor: user) do
      :ok ->
        {:noreply,
         apply_conversation_removal(socket, conversation, conversation_id, "Conversation deleted")}

      {:ok, _} ->
        {:noreply,
         apply_conversation_removal(socket, conversation, conversation_id, "Conversation deleted")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete conversation")}
    end
  end

  defp apply_conversation_removal(socket, conversation, conversation_id, message) do
    socket
    |> put_flash(:info, message)
    |> stream_delete(:conversations, conversation)
    |> maybe_navigate_chat_home(conversation_id)
  end

  defp maybe_navigate_chat_home(socket, conversation_id) do
    if socket.assigns[:conversation] && socket.assigns.conversation.id == conversation_id do
      push_navigate(socket, to: ~p"/chat")
    else
      socket
    end
  end

  defp remove_conversation_from_stream(socket, conversation_id) do
    case Enum.find(socket.assigns.streams.conversations.inserts, fn {_id, conv} ->
           conv.id == conversation_id
         end) do
      {_id, conversation} -> stream_delete(socket, :conversations, conversation)
      nil -> socket
    end
  end

  defp handle_submitted_message(%{assigns: %{conversation: nil}} = socket, message) do
    {:noreply, push_navigate(socket, to: ~p"/chat/#{message.conversation_id}")}
  end

  defp handle_submitted_message(socket, message) do
    socket
    |> assign_message_form()
    |> stream_insert(:messages, message, at: 0)
    |> push_event("reset_form", %{form_id: "message-form"})
    |> then(&{:noreply, &1})
  end

  defp handle_chat_command(_command, %{assigns: %{conversation: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "Create or select a conversation first")}
  end

  defp handle_chat_command(:clear, socket) do
    user = socket.assigns.current_user
    conversation = socket.assigns.conversation
    now = DateTime.utc_now()

    with {:ok, updated} <- Vmemo.Chat.clear_context(conversation, now, actor: user),
         {:ok, feedback} <-
           Vmemo.Chat.create_system_message(
             %{
               conversation_id: conversation.id,
               text: "Context cleared. History is preserved."
             },
             actor: user
           ) do
      {:noreply,
       socket
       |> assign(:conversation, updated)
       |> stream_insert(:messages, feedback, at: 0)
       |> push_event("reset_form", %{form_id: "message-form"})}
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

    with {:ok, updated} <-
           Vmemo.Chat.compact_context(conversation, now, summary, actor: user),
         {:ok, feedback} <-
           Vmemo.Chat.create_system_message(
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
       |> push_event("reset_form", %{form_id: "message-form"})}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to compact context")}
    end
  end
end

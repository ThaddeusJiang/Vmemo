defmodule Vmemo.Chat.Message.Changes.TouchConversation do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, message ->
      case Ash.get(Vmemo.Chat.Conversation, message.conversation_id, scope: context) do
        {:ok, conversation} ->
          _ =
            Vmemo.Chat.touch_last_message_at(
              conversation,
              DateTime.utc_now(),
              scope: context
            )

          {:ok, message}

        {:error, _} ->
          {:ok, message}
      end
    end)
  end
end

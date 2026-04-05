defmodule Vmemo.Chat do
  @moduledoc false
  use Ash.Domain, otp_app: :vmemo, extensions: [AshPhoenix]

  resources do
    resource Vmemo.Chat.Conversation do
      define :create_conversation, action: :create
      define :get_conversation, action: :read, get_by: [:id]
      define :update_conversation, action: :update
      define :archive_conversation, action: :archive
      define :delete_conversation, action: :destroy
      define :my_conversations
    end

    resource Vmemo.Chat.Message do
      define :message_history,
        action: :for_conversation,
        args: [:conversation_id],
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :create_message, action: :create
    end
  end
end

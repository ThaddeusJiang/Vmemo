defmodule Vmemo.Chat do
  @moduledoc false
  use Ash.Domain, otp_app: :vmemo, extensions: [AshPhoenix]

  alias Vmemo.Account.User

  resources do
    resource Vmemo.Chat.Conversation do
      define :create_conversation, action: :create
      define :create_image_scoped_conversation, action: :create_image_scoped
      define :get_conversation, action: :read, get_by: [:id]
      define :update_conversation, action: :update
      define :archive_conversation, action: :archive
      define :delete_conversation, action: :destroy
      define :clear_context, action: :clear_context, args: [:at]
      define :compact_context, action: :compact_context, args: [:at, :summary]
      define :touch_last_message_at, action: :touch_last_message_at, args: [:at]
      define :my_conversations
      define :conversations_for_image, action: :for_image, args: [:image_id]
    end

    resource Vmemo.Chat.Message do
      define :message_history,
        action: :for_conversation,
        args: [:conversation_id],
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :create_message, action: :create
      define :create_system_message, action: :create_system
    end
  end

  def list_conversations_by_initial_image(%User{} = user, image_id) when is_binary(image_id) do
    conversations_for_image!(image_id, actor: user)
  end
end

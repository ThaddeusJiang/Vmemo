defmodule Vmemo.Chat.Message.Changes.CreateConversationIfNotProvided do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    if changeset.arguments[:conversation_id] do
      Ash.Changeset.force_change_attribute(
        changeset,
        :conversation_id,
        changeset.arguments.conversation_id
      )
    else
      Ash.Changeset.before_action(changeset, fn changeset ->
        image_id = changeset.arguments[:image_id]
        conversation = create_missing_conversation(image_id, context)

        Ash.Changeset.force_change_attribute(changeset, :conversation_id, conversation.id)
      end)
    end
  end

  defp create_missing_conversation(image_id, context) do
    opts = Ash.Context.to_opts(context)

    if image_id do
      Vmemo.Chat.create_image_scoped_conversation!(%{title: nil, image_id: image_id}, opts)
    else
      Vmemo.Chat.create_conversation!(%{title: nil}, opts)
    end
  end
end

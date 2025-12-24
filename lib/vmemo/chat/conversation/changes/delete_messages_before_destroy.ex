defmodule Vmemo.Chat.Conversation.Changes.DeleteMessagesBeforeDestroy do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # With CASCADE delete configured in the database (see migration 20251223122250),
    # messages will be automatically deleted by PostgreSQL when the conversation is deleted.
    # This is more efficient than using Ash.bulk_destroy! and handles the self-referencing
    # relationship (response_to_id) automatically.
    #
    # The database CASCADE handles:
    # 1. Deleting all messages when conversation is deleted
    # 2. Recursively handling the self-referencing response_to_id constraint
    #
    # This change module is kept for consistency, but no manual deletion is needed.
    changeset
  end
end

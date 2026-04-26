defmodule Vmemo.Repo.Migrations.AddImageScopedChatFields do
  use Ecto.Migration

  def up do
    alter table(:chat_conversations) do
      add :kind, :text, null: false, default: "global"

      add :image_id,
          references(:memo_images,
            column: :id,
            name: "chat_conversations_image_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )

      add :last_message_at, :utc_datetime_usec
      add :context_reset_at, :utc_datetime_usec
      add :context_summary, :text
    end

    create index(:chat_conversations, [:user_id, :image_id, :inserted_at],
             name: "chat_conversations_user_image_inserted_idx"
           )

    alter table(:chat_messages) do
      add :attachments, {:array, :map}
      add :provider, :text
      add :tool_name, :text
    end
  end

  def down do
    alter table(:chat_messages) do
      remove :tool_name
      remove :provider
      remove :attachments
    end

    drop_if_exists index(:chat_conversations, [:user_id, :image_id, :inserted_at],
                     name: "chat_conversations_user_image_inserted_idx"
                   )

    alter table(:chat_conversations) do
      remove :context_summary
      remove :context_reset_at
      remove :last_message_at
      remove :image_id
      remove :kind
    end
  end
end

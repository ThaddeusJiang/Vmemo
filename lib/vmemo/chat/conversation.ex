defmodule Vmemo.Chat.Conversation do
  use Ash.Resource,
    otp_app: :vmemo,
    domain: Vmemo.Chat,
    extensions: [AshOban],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  oban do
    triggers do
      trigger :name_conversation do
        action :generate_name
        queue :conversations
        lock_for_update? false
        worker_module_name Vmemo.Chat.Message.Workers.NameConversation
        scheduler_module_name Vmemo.Chat.Message.Schedulers.NameConversation
        where expr(needs_title)
      end
    end
  end

  postgres do
    table "conversations"
    repo Vmemo.Repo

    custom_statements do
      statement :rls_conversations_isolation do
        up """
        ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
        ALTER TABLE conversations FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS conversations_rls_isolation ON conversations;
        CREATE POLICY conversations_rls_isolation ON conversations
          USING (
            CASE
              WHEN current_setting('vmemo.rls_bypass', true) = 'on' THEN true
              ELSE user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
            END
          )
          WITH CHECK (
            CASE
              WHEN current_setting('vmemo.rls_bypass', true) = 'on' THEN true
              ELSE user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
            END
          );
        """

        down """
        DROP POLICY IF EXISTS conversations_rls_isolation ON conversations;
        ALTER TABLE conversations NO FORCE ROW LEVEL SECURITY;
        ALTER TABLE conversations DISABLE ROW LEVEL SECURITY;
        """
      end
    end
  end

  actions do
    defaults [:read]

    destroy :destroy do
      require_atomic? false
      change Vmemo.Chat.Conversation.Changes.DeleteMessagesBeforeDestroy
    end

    create :create do
      accept [:title]
      change relate_actor(:user)
    end

    update :update do
      accept [:title]
    end

    update :generate_name do
      accept []
      transaction? false
      require_atomic? false
      change Vmemo.Chat.Conversation.Changes.GenerateName
    end

    update :archive do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :archived_at, DateTime.utc_now())
      end
    end

    read :my_conversations do
      filter expr(user_id == ^actor(:id) and is_nil(archived_at))

      prepare build(default_sort: [inserted_at: :desc])
    end
  end

  pub_sub do
    module VmemoWeb.Endpoint
    prefix "chat"

    publish_all :create, ["conversations", :user_id] do
      transform & &1.data
    end

    publish_all :update, ["conversations", :user_id] do
      transform & &1.data
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      public? true
    end

    attribute :archived_at, :utc_datetime do
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :messages, Vmemo.Chat.Message do
      public? true
    end

    belongs_to :user, Vmemo.Account.User do
      public? true
      allow_nil? false
    end
  end

  calculations do
    calculate :needs_title, :boolean do
      calculation expr(
                    is_nil(title) and
                      (count(messages) > 3 or
                         (count(messages) > 1 and inserted_at < ago(10, :minute)))
                  )
    end
  end
end

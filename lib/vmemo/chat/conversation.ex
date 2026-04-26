defmodule Vmemo.Chat.Conversation do
  @moduledoc false
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
    table "chat_conversations"
    repo Vmemo.Repo
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
      change set_attribute(:kind, "global")
    end

    create :create_image_scoped do
      accept [:title, :image_id]
      change relate_actor(:user)
      change set_attribute(:kind, "image_scoped")

      change fn changeset, context ->
        Ash.Changeset.after_action(changeset, fn _changeset, conversation ->
          case Ash.get(Vmemo.Memo.Image, conversation.image_id, scope: context) do
            {:ok, image} ->
              _ =
                Vmemo.Chat.create_system_message(
                  %{
                    conversation_id: conversation.id,
                    text: "Image context loaded.",
                    attachments: [
                      %{
                        id: image.id,
                        url: image.url,
                        note: image.note || ""
                      }
                    ],
                    provider: "system",
                    tool_name: "image_context"
                  },
                  scope: context
                )

              {:ok, conversation}

            _ ->
              {:ok, conversation}
          end
        end)
      end
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

    update :touch_last_message_at do
      accept []
      argument :at, :utc_datetime_usec, allow_nil?: false
      require_atomic? false
      change set_attribute(:last_message_at, arg(:at))
    end

    update :clear_context do
      accept []
      argument :at, :utc_datetime_usec, allow_nil?: false
      require_atomic? false

      change set_attribute(:context_reset_at, arg(:at))
      change set_attribute(:context_summary, nil)
    end

    update :compact_context do
      accept []
      argument :at, :utc_datetime_usec, allow_nil?: false
      argument :summary, :string, allow_nil?: false
      require_atomic? false

      change set_attribute(:context_reset_at, arg(:at))
      change set_attribute(:context_summary, arg(:summary))
    end

    read :my_conversations do
      filter expr(user_id == ^actor(:id) and is_nil(archived_at))

      prepare build(default_sort: [inserted_at: :desc])
    end

    read :for_image do
      argument :image_id, :uuid, allow_nil?: false

      filter expr(
               user_id == ^actor(:id) and
                 kind == "image_scoped" and
                 image_id == ^arg(:image_id) and
                 is_nil(archived_at)
             )

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

  validations do
    validate one_of(:kind, ["image_scoped", "global"]),
      message: "kind must be one of: image_scoped, global"
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      public? true
    end

    attribute :archived_at, :utc_datetime do
      public? true
    end

    attribute :kind, :string do
      public? true
      allow_nil? false
      default "global"
    end

    attribute :image_id, :uuid do
      public? true
    end

    attribute :last_message_at, :utc_datetime_usec do
      public? true
    end

    attribute :context_reset_at, :utc_datetime_usec do
      public? true
    end

    attribute :context_summary, :string do
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

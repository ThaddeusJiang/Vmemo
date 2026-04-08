defmodule Vmemo.Memo.UploadSession do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.Memo,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "memo_upload_sessions"
    repo Vmemo.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:user_id, :note_id, :client_session_key, :status, :total_count]
    end

    update :update do
      accept [
        :note_id,
        :status,
        :total_count,
        :completed_count,
        :failed_count,
        :last_error
      ]

      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :user_id, :uuid, allow_nil?: false
    attribute :note_id, :uuid
    attribute :client_session_key, :string, allow_nil?: false
    attribute :status, :string, allow_nil?: false, default: "pending"
    attribute :total_count, :integer, allow_nil?: false, default: 0
    attribute :completed_count, :integer, allow_nil?: false, default: 0
    attribute :failed_count, :integer, allow_nil?: false, default: 0
    attribute :last_error, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

end

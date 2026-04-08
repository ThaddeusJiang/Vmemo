defmodule Vmemo.Memo.UploadSessionItem do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.Memo,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "memo_upload_session_items"
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
      accept [
        :upload_session_id,
        :order_index,
        :client_file_fingerprint,
        :file_name,
        :mime_type,
        :size,
        :status
      ]
    end

    update :update do
      accept [:photo_id, :status, :retry_count, :last_error]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :upload_session_id, :uuid, allow_nil?: false
    attribute :order_index, :integer, allow_nil?: false
    attribute :client_file_fingerprint, :string, allow_nil?: false
    attribute :file_name, :string, allow_nil?: false
    attribute :mime_type, :string
    attribute :size, :integer, allow_nil?: false
    attribute :photo_id, :uuid
    attribute :status, :string, allow_nil?: false, default: "queued"
    attribute :retry_count, :integer, allow_nil?: false, default: 0
    attribute :last_error, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :upload_session, Vmemo.Memo.UploadSession do
      allow_nil? false
      attribute_writable? true
      source_attribute :upload_session_id
    end
  end
end

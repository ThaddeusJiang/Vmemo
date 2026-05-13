defmodule Vmemo.Memo.Tag do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.Memo,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "memo_tags"
    repo Vmemo.Repo
  end

  admin do
    table_columns([:id, :name, :inserted_at, :updated_at])
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :read
    define :create
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name]
      upsert? true
      upsert_identity :unique_name
      upsert_fields [:name]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :images, Vmemo.Memo.Image do
      through Vmemo.Memo.ImageTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :image_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end

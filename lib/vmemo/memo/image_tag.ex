defmodule Vmemo.Memo.ImageTag do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.Memo,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "memo_images_tags"
    repo Vmemo.Repo
  end

  admin do
    table_columns([:id, :image_id, :tag_id, :inserted_at])
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:image_id, :tag_id]
      upsert? true
      upsert_identity :unique_image_tag_pair
      upsert_fields [:image_id, :tag_id]
    end

    create :import do
      accept [:image_id, :tag_id]
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :image, Vmemo.Memo.Image do
      allow_nil? false
      attribute_writable? true
      source_attribute :image_id
    end

    belongs_to :tag, Vmemo.Memo.Tag do
      allow_nil? false
      attribute_writable? true
      source_attribute :tag_id
    end
  end

  identities do
    identity :unique_image_tag_pair, [:image_id, :tag_id]
  end
end

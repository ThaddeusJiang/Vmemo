defmodule Vmemo.Account.UserProfile do
  @moduledoc false

  use Ash.Resource,
    domain: Vmemo.Account,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "auth_user_profiles"
    repo Vmemo.Repo
  end

  admin do
    name "UserProfile"

    table_columns([
      :id,
      :user_id,
      :name,
      :language,
      :appearance,
      :avatar_file_id,
      :inserted_at
    ])
  end

  code_interface do
    define :create
    define :update
    define :get_by_user_id, args: [:user_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :user_id,
        :name,
        :language,
        :appearance,
        :avatar_file_id
      ]
    end

    update :update do
      accept [
        :name,
        :language,
        :appearance,
        :avatar_file_id
      ]

      require_atomic? false
    end

    read :get_by_user_id do
      get? true
      argument :user_id, :uuid, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
    end
  end

  validations do
    validate present(:user_id), on: [:create]
    validate present(:name), on: [:create, :update]

    validate one_of(:language, ["en", "zh", "ja"]),
      on: [:create, :update],
      message: "must be one of: en, zh, ja"

    validate one_of(:appearance, ["system", "light", "dark"]),
      on: [:create, :update],
      message: "must be one of: system, light, dark"
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 120
    end

    attribute :avatar_file_id, :string do
      public? true
      constraints max_length: 255
    end

    attribute :language, :string do
      allow_nil? false
      default "en"
      public? true
    end

    attribute :appearance, :string do
      allow_nil? false
      default "system"
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Vmemo.Account.User do
      attribute_type :uuid
      attribute_writable? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_user_profile, [:user_id]
  end
end

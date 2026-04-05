defmodule Vmemo.Account.UserToken do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.AccountDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource, AshAdmin.Resource]

  postgres do
    table "user_tokens"
    repo Vmemo.Repo
  end

  token do
  end

  admin do
    name "UserToken"
  end

  actions do
    defaults [:read, :destroy, :create]

    update :update_user_id do
      accept [:user_id]
    end
  end

  attributes do
    attribute :jti, :string,
      allow_nil?: false,
      sensitive?: true,
      primary_key?: true,
      public?: true

    attribute :aud, :string, allow_nil?: true, public?: true
    attribute :exp, :utc_datetime, allow_nil?: true, public?: true
    attribute :iss, :string, allow_nil?: true, public?: true
    attribute :sub, :string, allow_nil?: true, public?: true
    attribute :typ, :string, allow_nil?: true, public?: true
    attribute :user_id, :uuid, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Vmemo.Account.User do
      attribute_type :uuid
      attribute_writable? true
    end
  end
end

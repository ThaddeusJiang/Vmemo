defmodule Vmemo.Account.AshUserToken do
  use Ash.Resource,
    domain: Vmemo.AccountDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  token do
  end

  postgres do
    table "ash_user_tokens"
    repo Vmemo.AshRepo
  end

  attributes do
    attribute :jti, :string, allow_nil?: false, sensitive?: true, primary_key?: true, public?: true
    attribute :aud, :string, allow_nil?: false
    attribute :exp, :utc_datetime, allow_nil?: false
    attribute :iss, :string, allow_nil?: false
    attribute :sub, :string, allow_nil?: false
    attribute :typ, :string, allow_nil?: false
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :ash_user, Vmemo.Account.AshUser do
      attribute_type :uuid
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy, :create]
  end
end

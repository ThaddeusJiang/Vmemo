defmodule Vmemo.Account.AshUser do
  use Ash.Resource,
    domain: Vmemo.AccountDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  authentication do
    session_identifier :jti

    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? true
      end
    end

    tokens do
      enabled? true
      token_lifetime 60 * 24 * 60 * 60
      signing_secret "m007g/tykiNHADOKiYRqEEHSTJpKMbBKzIkQMuDjyKLjVUlJA63WXda4DOeTfWNC"
      token_resource Vmemo.Account.AshUserToken
    end
  end

  postgres do
    table "ash_users"
    repo Vmemo.AshRepo
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false, public?: true
    attribute :password, :string, allow_nil?: true, sensitive?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :confirmed_at, :utc_datetime, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    has_many :api_tokens, Vmemo.Account.ApiToken
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:email, :password]
      change &hash_password/2
    end

    update :update_profile do
      accept [:email]
    end

    update :change_password do
      accept [:password]
      change &hash_password/2
      require_atomic? false
    end
  end

  code_interface do
    define :get_by_email, action: :read, get_by: [:email]
    define :register_with_password, action: :register
    define :sign_in_with_password, action: :sign_in_with_password
  end

  # 密码哈希函数
  def hash_password(changeset, _context) do
    case Ash.Changeset.get_attribute(changeset, :password) do
      nil ->
        changeset

      password ->
        hashed_password = Bcrypt.hash_pwd_salt(password)
        Ash.Changeset.change_attribute(changeset, :hashed_password, hashed_password)
    end
  end
end

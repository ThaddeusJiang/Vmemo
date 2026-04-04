defmodule Vmemo.Account.User do
  use Ash.Resource,
    domain: Vmemo.AccountDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication, AshAdmin.Resource]

  postgres do
    table "users"
    repo Vmemo.Repo
  end

  authentication do
    session_identifier(:jti)

    strategies do
      password :password do
        identity_field(:email)
        sign_in_tokens_enabled?(true)
      end
    end

    tokens do
      enabled?(true)
      token_lifetime(60 * 24 * 60 * 60)
      signing_secret(&get_signing_secret/2)
      token_resource(Vmemo.Account.UserToken)
    end
  end

  admin do
    name "User"
  end

  code_interface do
    define :get_by_email, action: :read, get_by: [:email]
    define :register_with_password, action: :register
    define :sign_in_with_password, action: :sign_in_with_password
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:email]

      argument :password, :string, allow_nil?: false
      argument :password_confirmation, :string, allow_nil?: true

      change &hash_password/2
    end

    create :import do
      accept [:id, :email, :hashed_password, :confirmed_at]
    end

    update :update_profile do
      accept [:email, :confirmed_at]
      require_atomic? false
    end

    update :change_password do
      argument :password, :string, allow_nil?: false
      argument :password_confirmation, :string, allow_nil?: true

      validate confirm(:password, :password_confirmation),
        message: "does not match password"

      change &hash_password/2
      require_atomic? false
    end

    update :reset_password do
      argument :password, :string, allow_nil?: false
      argument :password_confirmation, :string, allow_nil?: true

      validate confirm(:password, :password_confirmation),
        message: "does not match password"

      change &hash_password/2
      require_atomic? false
    end
  end

  validations do
    validate present(:email), on: [:create, :update]
    validate match(:email, ~r/@/), message: "must have the @ sign and no spaces"

    validate fn changeset, _context ->
               password = Ash.Changeset.get_argument(changeset, :password)

               cond do
                 is_nil(password) ->
                   :ok

                 String.length(password) < 8 ->
                   {:error, field: :password, message: "should be at least 8 character(s)"}

                 String.length(password) > 72 ->
                   {:error, field: :password, message: "should be at most 72 character(s)"}

                 true ->
                   :ok
               end
             end,
             on: [:create, :update]
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :email, :string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :confirmed_at, :utc_datetime, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :api_tokens, Vmemo.Account.ApiToken
  end

  identities do
    identity :unique_email, [:email]
  end

  # 密码哈希函数
  def hash_password(changeset, _context) do
    case Ash.Changeset.get_argument(changeset, :password) do
      nil ->
        changeset

      password ->
        hashed_password = Bcrypt.hash_pwd_salt(password)
        Ash.Changeset.change_attribute(changeset, :hashed_password, hashed_password)
    end
  end

  defp get_signing_secret(_resource, _opts) do
    case Application.get_env(:vmemo, :secret_key_base) do
      nil -> :error
      secret -> {:ok, secret}
    end
  end
end

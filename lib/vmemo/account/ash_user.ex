defmodule Vmemo.Account.AshUser do
  use Ash.Resource,
    domain: Vmemo.AccountDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table "ash_users"
    repo Vmemo.AshRepo
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

      signing_secret(
        Application.compile_env(:vmemo, :jwt_signing_secret, "default_secret_for_compilation")
      )

      token_resource(Vmemo.Account.AshUserToken)
    end
  end

  code_interface do
    define :get_by_email, action: :read, get_by: [:email]
    define :register_with_password, action: :register
    define :sign_in_with_password, action: :sign_in_with_password
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:email, :password]

      change fn changeset, _context ->
        # 如果没有提供 ID，生成一个 UUID 字符串
        case Ash.Changeset.get_attribute(changeset, :id) do
          nil ->
            id = Ecto.UUID.generate()
            Ash.Changeset.change_attribute(changeset, :id, id)

          _existing_id ->
            changeset
        end
      end

      # Validate required fields with custom messages - run before hash_password
      change &validate_required_fields/2

      change &hash_password/2
    end

    update :update_profile do
      accept [:email, :confirmed_at]
    end

    update :change_password do
      accept [:password]
      change &hash_password/2
      require_atomic? false
    end
  end

  attributes do
    attribute :id, :string do
      allow_nil? false
      primary_key? true
    end

    attribute :email, :string do
      allow_nil? false
      public? true

      constraints match: ~r/^[^\s]+@[^\s]+$/,
                  max_length: 160
    end

    attribute :password, :string do
      allow_nil? true
      sensitive? true

      constraints min_length: 12,
                  max_length: 72
    end

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

  # 验证必填字段
  defp validate_required_fields(changeset, _context) do
    # Get the attributes to check what was actually provided
    # When using 'accept', values are set as attributes, not arguments
    email = Ash.Changeset.get_attribute(changeset, :email)
    password = Ash.Changeset.get_attribute(changeset, :password)

    changeset
    |> validate_field_present(:email, email)
    |> validate_field_present(:password, password)
  end

  defp validate_field_present(changeset, field, value) do
    # Only add "can't be blank" error if:
    # 1. Value is nil or empty string
    # 2. There are no existing errors for this field (to avoid duplicate errors)
    if (is_nil(value) or value == "") and not has_error_for_field?(changeset, field) do
      Ash.Changeset.add_error(changeset, field: field, message: "can't be blank")
    else
      changeset
    end
  end

  defp has_error_for_field?(changeset, field) do
    Enum.any?(changeset.errors, fn error ->
      Map.get(error, :field) == field
    end)
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

defmodule Vmemo.Account.ApiToken do
  use Ash.Resource,
    domain: Vmemo.AccountDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  require Ash.Query

  postgres do
    table "api_tokens"
    repo Vmemo.AshRepo
  end

  admin do
    table_columns([:id, :name, :description, :is_active, :expires_at, :last_used_at, :user_id, :inserted_at])
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get_by_id, args: [:id]
    define :get_by_user_and_id, args: [:id, :user_id]
    define :list_by_user, args: [:user_id]
    define :verify_token, args: [:token]
    define :toggle_status, args: [:id]
    define :get_expiring_tokens, args: [:user_id, :days]
    define :get_expired_tokens, args: [:user_id]
  end

  attributes do
    integer_primary_key :id, generated?: true

    attribute :token_hash, :string do
      allow_nil? false
      constraints max_length: 64
    end

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :expires_at, :utc_datetime
    attribute :last_used_at, :utc_datetime
    attribute :is_active, :boolean do
      default true
    end

    attribute :created_at, :utc_datetime do
      allow_nil? false
    end

    attribute :user_id, :integer do
      allow_nil? false
    end

    attribute :ash_user_id, :uuid do
      allow_nil? true
    end

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
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :expires_at, :user_id, :token_hash]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:created_at, DateTime.utc_now() |> DateTime.truncate(:second))
      end

      validate fn changeset, _context ->
        expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)

        if expires_at && DateTime.compare(expires_at, DateTime.utc_now()) != :gt do
          Ash.Changeset.add_error(changeset, field: :expires_at, message: "must be in the future")
        else
          :ok
        end
      end
    end

    update :update do
      accept [:name, :description, :expires_at]
      require_atomic? false

      validate fn changeset, _context ->
        expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)

        if expires_at && DateTime.compare(expires_at, DateTime.utc_now()) != :gt do
          Ash.Changeset.add_error(changeset, field: :expires_at, message: "must be in the future")
        else
          :ok
        end
      end
    end

    read :get_by_id do
      get? true
      argument :id, :integer, allow_nil?: false

      filter expr(id == ^arg(:id))
    end

    read :get_by_user_and_id do
      get? true
      argument :id, :integer, allow_nil?: false
      argument :user_id, :integer, allow_nil?: false

      filter expr(id == ^arg(:id) and user_id == ^arg(:user_id))
    end

    read :list_by_user do
      argument :user_id, :integer, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
    end

    read :verify_token do
      get? true
      argument :token, :string, allow_nil?: false

      prepare fn query, _context ->
        token = Ash.Query.get_argument(query, :token)
        hash = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

        Ash.Query.filter(query, token_hash: hash, is_active: true)
      end
    end

    update :toggle_status do
      argument :id, :integer, allow_nil?: false
      require_atomic? false

      change fn changeset, _context ->
        id = Ash.Query.get_argument(changeset, :id)

        case Vmemo.Account.ApiToken.get_by_id(id) do
          {:ok, token} ->
            new_status = !token.is_active
            Ash.Changeset.change_attribute(changeset, :is_active, new_status)
          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :id, message: "Token not found")
        end
      end
    end

    read :get_expiring_tokens do
      argument :user_id, :integer, allow_nil?: false
      argument :days, :integer, default: 7

      prepare fn query, _context ->
        user_id = Ash.Query.get_argument(query, :user_id)
        days = Ash.Query.get_argument(query, :days)
        cutoff_date = DateTime.utc_now() |> DateTime.add(days * 24 * 60 * 60, :second)

        Ash.Query.filter(query,
          user_id: user_id,
          is_active: true,
          expires_at: [less_than_or_equal_to: cutoff_date, greater_than: DateTime.utc_now()]
        )
        |> Ash.Query.sort(expires_at: :asc)
      end
    end

    read :get_expired_tokens do
      argument :user_id, :integer, allow_nil?: false

      prepare fn query, _context ->
        user_id = Ash.Query.get_argument(query, :user_id)

        Ash.Query.filter(query,
          user_id: user_id,
          is_active: true,
          expires_at: [less_than_or_equal_to: DateTime.utc_now()]
        )
        |> Ash.Query.sort(expires_at: :desc)
      end
    end
  end

  # Token 生成和 hash 计算
  def generate_token do
    # 生成 32 字节的随机 token
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    # 添加前缀便于识别
    prefixed_token = "vmemo_" <> token
    # 计算 hash
    hash = :crypto.hash(:sha256, prefixed_token) |> Base.encode16(case: :lower)
    {prefixed_token, hash}
  end

  # 验证 token
  def verify_token(token, token_hash) do
    computed_hash = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
    computed_hash == token_hash
  end
end

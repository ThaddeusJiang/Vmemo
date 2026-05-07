defmodule Vmemo.Account.ApiToken do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.Account,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  require Ash.Query

  postgres do
    table "auth_api_tokens"
    repo Vmemo.Repo
  end

  admin do
    name "Account"

    table_columns([
      :id,
      :name,
      :description,
      :is_active,
      :expires_at,
      :last_used_at,
      :user_id,
      :inserted_at
    ])
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
    define :get_today_used_tokens, args: [:user_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :expires_at, :user_id, :token_hash]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(
          :created_at,
          DateTime.utc_now() |> DateTime.truncate(:second)
        )
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
      accept [:name, :description, :expires_at, :last_used_at, :usage_count]
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
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))
    end

    read :get_by_user_and_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id) and user_id == ^arg(:user_id))
    end

    read :list_by_user do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [created_at: :desc])
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
      argument :id, :uuid, allow_nil?: false
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
      argument :user_id, :uuid, allow_nil?: false
      argument :days, :integer, default: 7

      prepare fn query, _context ->
        user_id = Ash.Query.get_argument(query, :user_id)
        days = Ash.Query.get_argument(query, :days)
        now = DateTime.utc_now()
        cutoff_date = DateTime.add(now, days * 24 * 60 * 60, :second)

        query
        |> Ash.Query.filter(user_id == ^user_id and is_active == true)
        |> Ash.Query.filter(
          expr(not is_nil(expires_at) and expires_at <= ^cutoff_date and expires_at > ^now)
        )
        |> Ash.Query.sort(expires_at: :asc)
      end
    end

    read :get_expired_tokens do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        user_id = Ash.Query.get_argument(query, :user_id)
        now = DateTime.utc_now()

        query
        |> Ash.Query.filter(user_id == ^user_id and is_active == true)
        |> Ash.Query.filter(expr(not is_nil(expires_at) and expires_at <= ^now))
        |> Ash.Query.sort(expires_at: :desc)
      end
    end

    read :get_today_used_tokens do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        require Ash.Query

        user_id = Ash.Query.get_argument(query, :user_id)
        today = Date.utc_today()
        today_start = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
        today_end = DateTime.new!(today, ~T[23:59:59.999999], "Etc/UTC")

        query
        |> Ash.Query.filter(user_id == ^user_id)
        |> Ash.Query.filter(
          expr(
            not is_nil(last_used_at) and last_used_at >= ^today_start and
              last_used_at <= ^today_end
          )
        )
      end
    end
  end

  attributes do
    uuid_primary_key :id

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

    attribute :usage_count, :integer do
      default 0
      allow_nil? false
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :created_at, :utc_datetime do
      allow_nil? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Vmemo.Account.User do
      attribute_type :string
      attribute_writable? true
    end
  end

  # Token generation and hash computation
  def generate_token do
    # Generate a 32-byte random token
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    # Add prefix for easier identification
    prefixed_token = "vmemo_" <> token
    # Compute hash
    hash = :crypto.hash(:sha256, prefixed_token) |> Base.encode16(case: :lower)
    {prefixed_token, hash}
  end

  # Verify token
  def verify_token(token, token_hash) do
    computed_hash = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
    computed_hash == token_hash
  end

  def list_user_tokens(user), do: list_by_user(user.id, actor: user)

  def get_user_token!(user, id) do
    case get_by_user_and_id(id, user.id, actor: user) do
      {:ok, token} -> token
      {:error, _} -> raise "No API token found with id: #{id} for user: #{user.id}"
    end
  end

  def create_for_user(user, attrs) do
    expires_at = attrs |> fetch_expires_at_param() |> parse_expires_at()

    attrs_with_user =
      attrs
      |> normalize_create_attrs()
      |> Map.put(:expires_at, expires_at)
      |> Map.put(:user_id, user.id)

    {raw_token, hash} = generate_token()
    attrs_with_hash = Map.put(attrs_with_user, :token_hash, hash)

    case create(attrs_with_hash, actor: user) do
      {:ok, api_token} -> {:ok, api_token, raw_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete_for_user(api_token, actor), do: destroy(api_token, actor: actor)
  def toggle_status_for_user(api_token, actor), do: toggle_status(api_token.id, actor: actor)
  def get_expiring_for_user(user, days \\ 7), do: get_expiring_tokens(user.id, days, actor: user)
  def get_expired_for_user(user), do: get_expired_tokens(user.id, actor: user)
  def get_today_used_for_user(user), do: get_today_used_tokens(user.id, actor: user)

  def count_today_usage_for_user(user) do
    with {:ok, tokens} <- get_today_used_for_user(user) do
      {:ok, Enum.map(tokens, &(&1.usage_count || 0)) |> Enum.sum()}
    end
  end

  def verify_api_token(token) do
    case verify_token(token) do
      {:ok, api_token} ->
        if api_token.expires_at &&
             DateTime.compare(DateTime.utc_now(), api_token.expires_at) == :gt do
          {:error, "Token expired"}
        else
          update_usage(api_token)
          {:ok, Ash.load!(api_token, :user)}
        end

      {:error, _} ->
        {:error, "Invalid token"}
    end
  end

  defp fetch_expires_at_param(attrs) when is_map(attrs) do
    Map.get(attrs, "expires_at") || Map.get(attrs, :expires_at)
  end

  defp normalize_create_attrs(attrs) when is_map(attrs) do
    %{
      name: Map.get(attrs, "name") || Map.get(attrs, :name),
      description: Map.get(attrs, "description") || Map.get(attrs, :description)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_expires_at("30"), do: expires_in_days(30)
  defp parse_expires_at("90"), do: expires_in_days(90)
  defp parse_expires_at("180"), do: expires_in_days(180)
  defp parse_expires_at("never"), do: nil
  defp parse_expires_at(nil), do: expires_in_days(90)

  defp parse_expires_at(date) when is_binary(date) do
    case DateTime.from_iso8601(date <> ":00") do
      {:ok, datetime, _} -> DateTime.truncate(datetime, :second)
      {:error, _} -> expires_in_days(90)
    end
  end

  defp parse_expires_at(%DateTime{} = date), do: DateTime.truncate(date, :second)
  defp parse_expires_at(_), do: expires_in_days(90)

  defp expires_in_days(days) do
    DateTime.utc_now()
    |> DateTime.add(days * 24 * 60 * 60, :second)
    |> DateTime.truncate(:second)
  end

  defp update_usage(api_token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    current_count = api_token.usage_count || 0

    case update(
           api_token,
           %{last_used_at: now, usage_count: current_count + 1},
           actor: api_token
         ) do
      {:ok, _updated_token} -> :ok
      {:error, _changeset} -> :error
    end
  end
end

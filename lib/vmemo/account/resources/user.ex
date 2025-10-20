defmodule Vmemo.Account.Resources.User do
  use Ash.Resource,
    domain: Vmemo.Account.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table "account_users"
    repo Vmemo.Repo
  end

  attributes do
    integer_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
      constraints [
        match: ~r/^[^\s]+@[^\s]+$/,
        max_length: 160
      ]
    end

    attribute :display_name, :string do
      allow_nil? true
      public? true
      constraints [
        min_length: 2,
        max_length: 160
      ]
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        hash_provider AshAuthentication.BcryptProvider
        confirmation_required? true
        
        resettable do
          sender Vmemo.Account.Senders.SendPasswordResetEmail
        end
      end
    end

    tokens do
      enabled? true
      token_resource Vmemo.Account.Resources.Token
      signing_secret fn _, _ ->
        Application.fetch_env(:vmemo, VmemoWeb.Endpoint)
        |> case do
          {:ok, endpoint_config} ->
            Keyword.fetch(endpoint_config, :secret_key_base)
          :error ->
            :error
        end
      end
    end

    session_identifier :jti
  end

  identities do
    identity :unique_email, [:email]
  end

  actions do
    defaults [:read]

    read :get_by_email do
      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    read :by_id do
      argument :id, :uuid do
        allow_nil? false
      end

      filter expr(id == ^arg(:id))
    end

    update :update_display_name do
      accept [:display_name]
    end

    update :update_email do
      accept [:email]
    end

    update :confirm do
      accept []
      change set_attribute(:confirmed_at, &DateTime.utc_now/0)
    end
  end

  code_interface do
    define :get_by_email, args: [:email]
    define :by_id, args: [:id]
    define :update_display_name
    define :update_email
    define :confirm
  end
end

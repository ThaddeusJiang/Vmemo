defmodule Vmemo.Account.Resources.Token do
  use Ash.Resource,
    domain: Vmemo.Account.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "account_users_tokens"
    repo Vmemo.Repo
  end

  token do
    domain Vmemo.Account.Domain
  end
end

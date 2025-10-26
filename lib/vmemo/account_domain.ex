defmodule Vmemo.AccountDomain do
  use Ash.Domain,
    extensions: [
      AshAdmin.Domain,
      AshAuthentication.Domain
    ]

  admin do
    show?(true)
  end

  resources do
    resource Vmemo.Account.AshUser
    resource Vmemo.Account.AshUserToken
    resource Vmemo.Account.ApiToken
  end

  authorization do
    require_actor? false
  end
end

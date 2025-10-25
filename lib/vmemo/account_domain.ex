defmodule Vmemo.AccountDomain do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  authorization do
    require_actor? true
  end

  resources do
    resource Vmemo.Account.ApiToken
  end
end

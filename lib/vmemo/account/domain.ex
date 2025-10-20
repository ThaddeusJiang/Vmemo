defmodule Vmemo.Account.Domain do
  use Ash.Domain

  resources do
    resource Vmemo.Account.Resources.User
    resource Vmemo.Account.Resources.Token
  end
end

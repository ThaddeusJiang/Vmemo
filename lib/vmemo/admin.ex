defmodule Vmemo.Admin do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource Vmemo.Admin.ImportRequest
  end

  authorization do
    require_actor? false
  end
end

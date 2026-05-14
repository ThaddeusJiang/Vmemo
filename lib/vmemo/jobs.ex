defmodule Vmemo.Jobs do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource Vmemo.Jobs.Job
  end

  authorization do
    require_actor? true
  end
end

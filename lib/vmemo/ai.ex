defmodule Vmemo.Ai do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource Vmemo.Ai.VisionRequest
  end

  authorization do
    require_actor? true
  end
end

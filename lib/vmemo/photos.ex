defmodule Vmemo.Photos do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource Vmemo.Photos.Photo
    resource Vmemo.Photos.Note
    resource Vmemo.Photos.PhotoNote
    resource Vmemo.Photos.PhotoMoondreamRequest
  end

  authorization do
    require_actor? true
  end
end

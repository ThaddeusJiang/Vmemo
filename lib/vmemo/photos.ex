defmodule Vmemo.Photos do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Vmemo.Photos.Photo
    resource Vmemo.Photos.Note
    resource Vmemo.Photos.PhotoNote
  end

  admin do
    show? true
  end
end

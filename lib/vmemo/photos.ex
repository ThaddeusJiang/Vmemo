defmodule Vmemo.Photos do
  use Ash.Domain

  resources do
    resource(Vmemo.Photos.Photo)
    resource(Vmemo.Photos.Note)
    resource(Vmemo.Photos.PhotoNote)
  end
end

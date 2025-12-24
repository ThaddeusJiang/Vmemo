defmodule Vmemo.Photos do
  use Ash.Domain,
    extensions: [AshAdmin.Domain, AshAi]

  admin do
    show?(true)
  end

  tools do
    tool :photo_search, Vmemo.Photos.Photo, :search_photos do
      description "Search for photos by text query or find similar photos based on a photo ID. Use this when users ask to find, search, or browse their photos."
    end
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

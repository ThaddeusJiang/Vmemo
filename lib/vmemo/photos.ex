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

  mcp_resources do
    # Photo URL resource - returns the photo URL as a string
    mcp_resource :photo_url, "vmemo://photo/:id/url", Vmemo.Photos.Photo, :get_photo_url,
      title: "Photo URL",
      description: "Get the URL of a photo by ID. Returns the photo URL as a string.",
      mime_type: "text/plain"

    # Photo HTML resource - returns the photo as HTML
    mcp_resource :photo_html, "vmemo://photo/:id/html", Vmemo.Photos.Photo, :get_photo_html,
      title: "Photo HTML",
      description:
        "Get a photo as HTML. Returns an HTML img tag with the photo URL, caption, and note.",
      mime_type: "text/html"

    # Photo Image resource - returns the photo as base64-encoded image data
    # Note: mime_type is a default/hint value. The actual image type is detected
    # from file content and included in the returned data URL (e.g., data:image/png;base64,...)
    mcp_resource :photo_image, "vmemo://photo/:id/image", Vmemo.Photos.Photo, :get_photo_image,
      title: "Photo Image",
      description:
        "Get a photo as base64-encoded image data. Returns the image data in data URL format. The actual MIME type (JPEG, PNG, GIF, WEBP) is auto-detected from file content and included in the data URL.",
      mime_type: "image/png"
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

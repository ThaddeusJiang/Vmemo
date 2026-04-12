defmodule Vmemo.Memo do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshAdmin.Domain, AshAi]

  admin do
    show?(true)
  end

  tools do
    tool :image_search, Vmemo.Memo.Image, :search_images do
      description "Search for images by text query or find similar images based on an image ID. Use this when users ask to find, search, or browse their images."
    end
  end

  mcp_resources do
    # Image URL resource - returns the image URL as a string
    mcp_resource :image_url, "vmemo://image/:id/url", Vmemo.Memo.Image, :get_image_url,
      title: "Image URL",
      description: "Get the URL of an image by ID. Returns the image URL as a string.",
      mime_type: "text/plain"

    # Image HTML resource - returns the image as HTML
    mcp_resource :image_html, "vmemo://image/:id/html", Vmemo.Memo.Image, :get_image_html,
      title: "Image HTML",
      description:
        "Get an image as HTML. Returns an HTML img tag with the image URL, caption, and note.",
      mime_type: "text/html"

    # Image Data resource - returns the image as base64-encoded image data
    # Note: mime_type is a default/hint value. The actual image type is detected
    # from file content and included in the returned data URL (e.g., data:image/png;base64,...)
    mcp_resource :image_data, "vmemo://image/:id/image", Vmemo.Memo.Image, :get_image_data,
      title: "Image Data",
      description:
        "Get an image as base64-encoded image data. Returns the image data in data URL format. The actual MIME type (JPEG, PNG, GIF, WEBP) is auto-detected from file content and included in the data URL.",
      mime_type: "image/png"
  end

  resources do
    resource Vmemo.Memo.Image
    resource Vmemo.Memo.Note
    resource Vmemo.Memo.ImageNote
  end

  authorization do
    require_actor? true
  end
end

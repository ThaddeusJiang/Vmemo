defmodule Vmemo.Memo do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshAdmin.Domain, AshAi]

  admin do
    show?(true)
  end

  tools do
    tool :image_search, Vmemo.Memo.Image, :search_images do
      description "Search for images by text query or visual similarity."

      argument :query, :string do
        description "Text query for full-text and semantic image search."
        default ""
      end

      argument :similar_image_id, :string do
        description "Optional image UUID to search for visually similar images."
        allow_nil? true
      end

      argument :page, :integer do
        description "Pagination page number, starting from 1."
        default 1
      end
    end

    tool :image_create, Vmemo.Memo.Image, :mcp_image_create do
      description "Create a new image for the current authenticated user."

      argument :file, :string do
        description "Image file as data URL, for example data:image/png;base64,..."
        allow_nil? false
      end

      argument :note, :string do
        description "Optional note text for this image."
        default ""
      end

      argument :caption, :string do
        description "Optional caption text for this image."
        default ""
      end
    end

    tool :image_read, Vmemo.Memo.Image, :mcp_image_read do
      description "Get image detail by ID."

      argument :id, :uuid do
        description "Image UUID."
        allow_nil? false
      end
    end

    tool :image_update, Vmemo.Memo.Image, :mcp_image_update do
      description "Update image metadata by ID."

      argument :id, :uuid do
        description "Image UUID."
        allow_nil? false
      end

      argument :note, :string do
        description "Optional new note text."
        allow_nil? true
      end

      argument :caption, :string do
        description "Optional new caption text."
        allow_nil? true
      end
    end

    tool :image_delete, Vmemo.Memo.Image, :mcp_image_delete do
      description "Delete image by ID."

      argument :id, :uuid do
        description "Image UUID."
        allow_nil? false
      end
    end
  end

  mcp_resources do
    # Image URL resource - returns the image URL as a string
    mcp_resource :image_url, "vmemo://image/url", Vmemo.Memo.Image, :get_image_url,
      title: "Image URL",
      description: "Get the URL of an image by ID. Returns the image URL as a string.",
      mime_type: "text/plain"

    # Image HTML resource - returns the image as HTML
    mcp_resource :image_html, "vmemo://image/html", Vmemo.Memo.Image, :get_image_html,
      title: "Image HTML",
      description:
        "Get an image as HTML. Returns an HTML img tag with the image URL, caption, and note.",
      mime_type: "text/html"

    # Image Data resource - returns the image as base64-encoded image data
    # Note: mime_type is a default/hint value. The actual image type is detected
    # from file content and included in the returned data URL (e.g., data:image/png;base64,...)
    mcp_resource :image_data, "vmemo://image/image", Vmemo.Memo.Image, :get_image_data,
      title: "Image Data",
      description:
        "Get an image as base64-encoded image data. Returns the image data in data URL format. The actual MIME type (JPEG, PNG, GIF, WEBP) is auto-detected from file content and included in the data URL.",
      mime_type: "image/png"
  end

  resources do
    resource Vmemo.Memo.Image
    resource Vmemo.Memo.Note
    resource Vmemo.Memo.ImageNote
    resource Vmemo.Memo.Tag
    resource Vmemo.Memo.ImageTag
  end

  authorization do
    require_actor? true
  end
end

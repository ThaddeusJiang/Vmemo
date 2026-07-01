defmodule Mix.Tasks.Storage.WarmImages do
  use Mix.Task

  alias Vmemo.Memo.ImageStorage
  alias Vmemo.Storage

  @shortdoc "Generate storage image variants for faster browser image loading"

  @moduledoc """
  Usage:
    mix storage.warm_images
    mix storage.warm_images --root data/storage/v1
    mix storage.warm_images --root data/storage/v1 --limit 100

  Generates fixed WebP display variants for original files under
  the configured `v1/<user_id>/images` storage root:

    * `<name>.thumb.webp` with max side 400px
    * `<name>.detail.webp` with max side 800px
  """

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} = OptionParser.parse(args, switches: [root: :string, limit: :integer])

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    root = Keyword.get(opts, :root, Storage.v1_path())
    warm_opts = Keyword.take(opts, [:limit])
    stats = ImageStorage.warm_variants!(root, warm_opts)

    Mix.shell().info(
      "storage image warmup complete: processed=#{stats.processed} failed=#{stats.failed}"
    )
  end
end

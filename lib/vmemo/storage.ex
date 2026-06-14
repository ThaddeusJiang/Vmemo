defmodule Vmemo.Storage do
  @moduledoc false

  alias Vmemo.Memo.ImageStorage

  def img(url, size), do: ImageStorage.thumbnail_url(url, size)
  def srcset(url), do: ImageStorage.srcset(url)
  def srcset(url, usage), do: ImageStorage.srcset(url, usage)
  def img_sizes(usage), do: ImageStorage.sizes(usage)
end

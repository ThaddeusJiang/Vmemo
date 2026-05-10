defmodule Vmemo.Storage do
  @moduledoc false

  alias Vmemo.Memo.ImageStorage

  def img(url, size), do: ImageStorage.thumbnail_url(url, size)
end

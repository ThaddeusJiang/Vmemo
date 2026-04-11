defmodule Vmemo.Memo.ImageStorage do
  @moduledoc """
  Image-focused alias module for `Vmemo.Memo.PhotoStorage`.
  """

  alias Vmemo.Memo.PhotoStorage

  defdelegate cp_file(src_path, user_id, filename), to: PhotoStorage
end

defmodule Vmemo.Memo.ImageNote do
  @moduledoc """
  Image-focused alias module for `Vmemo.Memo.PhotoNote`.
  """

  alias Vmemo.Memo.PhotoNote

  defdelegate create(attrs, opts \\ []), to: PhotoNote
  defdelegate read(opts \\ []), to: PhotoNote
  defdelegate destroy(record, opts \\ []), to: PhotoNote
end

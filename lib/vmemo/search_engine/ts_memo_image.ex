defmodule Vmemo.SearchEngine.TsMemoImage do
  @moduledoc """
  Image-focused alias module for Typesense memo image operations.

  This module delegates to `Vmemo.SearchEngine.TsPhoto` during the transition
  from `photo` naming to `image` naming.
  """

  alias Vmemo.SearchEngine.TsPhoto

  defdelegate parse(photo), to: TsPhoto
  defdelegate similarity_percentage(photo), to: TsPhoto
  defdelegate create(photo), to: TsPhoto
  defdelegate get_photo(id), to: TsPhoto
  defdelegate get(id, kind), to: TsPhoto
  defdelegate update_photo(photo), to: TsPhoto
  defdelegate delete_photo(id), to: TsPhoto
  defdelegate update_note(id, note), to: TsPhoto
  defdelegate update(id, photo), to: TsPhoto
  defdelegate update_caption(id, caption), to: TsPhoto
  defdelegate list_photos(opts \\ []), to: TsPhoto
  defdelegate count_photos(opts \\ []), to: TsPhoto
  defdelegate hybrid_search_photos(params, opts \\ []), to: TsPhoto
  defdelegate list_similar_photos(id, opts \\ []), to: TsPhoto
end

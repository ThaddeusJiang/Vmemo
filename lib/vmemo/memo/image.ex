defmodule Vmemo.Memo.Image do
  @moduledoc """
  Image-focused alias module for `Vmemo.Memo.Photo`.

  This keeps backward compatibility while callers gradually migrate from
  `Photo` naming to `Image` naming.
  """

  alias Vmemo.Memo.Photo

  defdelegate create_with_sync(attrs, opts \\ []), to: Photo
  defdelegate create_for_image_search(attrs, opts \\ []), to: Photo
  defdelegate create_immediate(attrs, opts \\ []), to: Photo
  defdelegate read(opts \\ []), to: Photo
  defdelegate update(record, attrs, opts \\ []), to: Photo
  defdelegate destroy(record, opts \\ []), to: Photo
  defdelegate get_with_notes(id, user_id, opts \\ []), to: Photo
  defdelegate hybrid_search(query, similar_photo_id, user_id, page, opts \\ []), to: Photo
  defdelegate hybrid_search_count(query, similar_photo_id, user_id, opts \\ []), to: Photo
  defdelegate list_similar(photo_id, user_id, opts \\ []), to: Photo
  defdelegate sync_typesense_by_id(photo_id, opts \\ []), to: Photo

  defdelegate ingest_temp_file_for_similarity_search(temp_path, storage_file_id, opts \\ []),
    to: Photo

  defdelegate update_search_engine(record, attrs \\ %{}, opts \\ []), to: Photo
  defdelegate request_generate_caption(record, attrs \\ %{}, opts \\ []), to: Photo
  defdelegate library_photos_count(user_id, opts \\ []), to: Photo
  defdelegate search_photos(opts \\ []), to: Photo
end

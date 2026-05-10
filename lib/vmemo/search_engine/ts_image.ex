defmodule Vmemo.SearchEngine.TsImage do
  @moduledoc """
  A module to interact with the image collection in Typesense.

  CRUD and search operations are supported.
  """
  alias SmallSdk.Typesense
  alias Vmemo.SearchEngine.TsNote

  @collection_name "memo_images"
  @note_collection_name "memo_notes"

  # Indexed as `_purpose` on Typesense (see `Image.inner_purpose` / `source :_purpose`).
  @purpose_search "search"

  defstruct [
    :id,
    :image,
    :note,
    :note_ids,
    :url,
    :file_id,
    :inserted_at,
    :inserted_by,
    :caption,
    :inner_purpose,
    :_vector_distance,
    :_text_match_info
  ]

  def parse(nil) do
    nil
  end

  def parse(image) do
    %__MODULE__{
      id: image["id"],
      image: image["image"],
      note: image["note"],
      note_ids: image["note_ids"],
      url: image["url"],
      file_id: image["file_id"],
      inserted_at: image["inserted_at"],
      inserted_by: image["inserted_by"],
      caption: image["caption"],
      inner_purpose: purpose_from_ts_document(image),
      _vector_distance: image["_vector_distance"],
      _text_match_info: image["_text_match_info"]
    }
  end

  def similarity_percentage(image) do
    case image._vector_distance do
      nil ->
        nil

      distance when is_number(distance) ->
        similarity = 1.0 - distance
        max(0, similarity * 100) |> Float.round(1)

      _ ->
        nil
    end
  end

  def create(image) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    case Typesense.create_document(
           @collection_name,
           Map.put_new(image, :inserted_at, now)
         ) do
      {:ok, document} -> {:ok, parse(document)}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_image(id) do
    case Typesense.get_document(@collection_name, id) do
      {:ok, nil} -> nil
      {:ok, image} -> parse(image)
      {:error, reason} -> {:error, reason}
    end
  end

  def get(id, :notes) do
    {:ok, image} = Typesense.get_document(@collection_name, id)

    image =
      case image do
        nil -> nil
        _ -> parse(image)
      end

    req = Typesense.build_request("/collections/#{@note_collection_name}/documents/search")

    res =
      Typesense.request(:get, req,
        params: [
          q: "*",
          filter_by: "(image_ids:#{id} || image_ids:#{id})"
        ]
      )

    {:ok, notes} = Typesense.handle_search_res(res)

    {:ok, %{image: image, notes: notes |> Enum.map(&TsNote.parse/1)}}
  end

  def update_image(image) do
    Typesense.update_document(@collection_name, image)
  end

  def delete_image(id) do
    Typesense.delete_document(@collection_name, id)
  end

  def update_note(id, note) do
    update_image(%{
      id: id,
      note: note
    })
  end

  def update(id, image) do
    update_image(Map.merge(image, %{id: id}))
  end

  def update_caption(id, caption) do
    update_image(%{
      id: id,
      caption: caption
    })
  end

  def list_images(opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "")
    req = Typesense.build_request("/collections/#{@collection_name}/documents/search")

    res =
      Typesense.request(:get, req,
        params: [
          q: "",
          query_by: "note,caption",
          exclude_fields: "image_embedding",
          filter_by: user_library_filter_by(user_id),
          page: 1,
          per_page: 100,
          sort_by: "inserted_at:desc"
        ]
      )

    {:ok, images} = Typesense.handle_search_res(res)

    images
  end

  def count_images(opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "")
    req = Typesense.build_request("/collections/#{@collection_name}/documents/search")

    res =
      Typesense.request(:get, req,
        params: [
          q: "*",
          query_by: "note,caption",
          filter_by: user_library_filter_by(user_id),
          per_page: 0
        ]
      )

    case Typesense.handle_response(res) do
      {:ok, data} -> data["found"] || 0
      _ -> 0
    end
  end

  @min_similarity_threshold 0.75
  @semantic_fallback_distance_threshold 0.95
  @multi_search_retry_attempts 1

  def hybrid_search_images({q, similar}, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "")
    page = Keyword.get(opts, :page, 1)
    per_page = 10

    q =
      case String.trim(q) do
        "" -> "*"
        q -> q
      end

    if is_nil(similar) or String.trim(to_string(similar)) == "" do
      choose_text_or_semantic_result(q, user_id, page, per_page)
    else
      search_similar_images(q, similar, user_id, page, per_page)
    end
  end

  defp choose_text_or_semantic_result(q, user_id, page, per_page) do
    text_result = search_text_images(q, user_id, page, per_page)

    if has_text_hits?(text_result) do
      text_result
    else
      fallback_to_semantic_or_text(q, user_id, page, per_page, text_result)
    end
  end

  defp has_text_hits?({_images, found, _current_page}) when found > 0, do: true
  defp has_text_hits?(_), do: false

  defp fallback_to_semantic_or_text("*", _user_id, _page, _per_page, text_result), do: text_result

  defp fallback_to_semantic_or_text(q, user_id, page, per_page, _text_result) do
    search_semantic_images(q, user_id, page, per_page)
  end

  defp search_text_images(q, user_id, page, per_page) do
    params = [
      q: q,
      query_by: "note,caption",
      filter_by: user_library_filter_by(user_id),
      sort_by: "inserted_at:desc",
      exclude_fields: "image_embedding",
      per_page: per_page,
      page: page
    ]

    case Typesense.search_documents(@collection_name, params) do
      {:ok, %{documents: images, found: found, page: current_page}} ->
        {images |> Enum.map(&parse/1), found, current_page}

      {:error, _reason} ->
        {[], 0, page}
    end
  end

  defp user_library_filter_by(user_id) do
    "inserted_by:#{user_id} && _purpose:!=#{@purpose_search}"
  end

  defp purpose_from_ts_document(image) when is_map(image) do
    case Map.get(image, "_purpose") || Map.get(image, "image_purpose") do
      nil ->
        nil

      "library" ->
        nil

      "similarity_query" ->
        "search"

      other when is_binary(other) ->
        other

      _ ->
        nil
    end
  end

  defp search_semantic_images(q, user_id, page, per_page) do
    req = Typesense.build_request("/multi_search")

    payload = %{
      "searches" => [
        %{
          "query_by" => "image_embedding",
          "q" => q,
          "vector_query" =>
            "image_embedding:([], k: 200, distance_threshold: #{@semantic_fallback_distance_threshold})",
          "collection" => @collection_name,
          "filter_by" => user_library_filter_by(user_id),
          "exclude_fields" => "image_embedding",
          "sort_by" => "_vector_distance:asc,inserted_at:desc",
          "drop_tokens_threshold" => 0,
          "per_page" => per_page,
          "page" => page
        }
      ]
    }

    res = post_multi_search(req, payload)

    case Typesense.handle_multi_search_res(res) do
      {:ok, {images, found, current_page}} ->
        {images |> Enum.map(&parse/1), found, current_page}
    end
  end

  defp search_similar_images(q, similar, user_id, page, per_page) do
    distance_threshold = 1.0 - @min_similarity_threshold

    req = Typesense.build_request("/multi_search")

    payload = %{
      "searches" => [
        %{
          "query_by" => "note,caption",
          "q" => q,
          "vector_query" =>
            "image_embedding:([], k: 500, distance_threshold: #{distance_threshold}, id:#{similar})",
          "collection" => @collection_name,
          "filter_by" => user_library_filter_by(user_id),
          "exclude_fields" => "image_embedding",
          "sort_by" => "_vector_distance:asc,_text_match:desc",
          "drop_tokens_threshold" => 0,
          "per_page" => per_page,
          "page" => page
        }
      ]
    }

    res = post_multi_search(req, payload)

    case Typesense.handle_multi_search_res(res) do
      {:ok, {images, found, current_page}} ->
        {images |> Enum.map(&parse/1), found, current_page}
    end
  end

  def list_similar_images(id, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "")
    limit = Keyword.get(opts, :limit, 50)
    distance_threshold = 1.0 - @min_similarity_threshold

    req = Typesense.build_request("/multi_search")

    payload = %{
      "searches" => [
        %{
          "collection" => @collection_name,
          "q" => "*",
          "vector_query" =>
            "image_embedding:([], k: #{limit * 2}, distance_threshold: #{distance_threshold}, id:#{id})",
          "filter_by" => user_library_filter_by(user_id),
          "exclude_fields" => "image_embedding",
          "sort_by" => "_vector_distance:asc",
          "per_page" => limit
        }
      ]
    }

    res = post_multi_search(req, payload)

    {:ok, {images, _found, _page}} = Typesense.handle_multi_search_res(res)

    images |> Enum.map(&parse/1)
  end

  defp post_multi_search(req, payload, attempt \\ 0) do
    case Typesense.request(:post, req, json: payload) do
      {:error, %Req.TransportError{reason: :closed} = reason}
      when attempt < @multi_search_retry_attempts ->
        _ = reason
        post_multi_search(req, payload, attempt + 1)

      other ->
        other
    end
  end
end

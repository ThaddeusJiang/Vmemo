```mermaid
classDiagram
    class Image {
        UUID id
        destroy()
        read()
        create_immediate(String url, String note, String caption, String file_id, ...)
        create_for_image_search(String url, String note, String caption, String file_id, ...)
        import(UUID id, String url, String note, String caption, ...)
        create_with_sync(String url, String note, String caption, String file_id, ...)
        update(String note, String caption, String url)
        sync_typesense()
        generate_caption()
        update_search_engine()
        request_generate_caption()
        set_typesense_status(String typesense_status)
        set_moondream_status(String moondream_status)
        sync_typesense_by_id(UUID image_id)
        ingest_temp_file_for_similarity_search(String temp_path, String storage_file_id)
        get_with_notes(String id, UUID user_id)
        hybrid_search(String query, String similar_image_id, UUID user_id, Integer page)
        hybrid_search_count(String query, String similar_image_id, UUID user_id)
        library_images_count(UUID user_id)
        search_images(String query, String similar_image_id, Integer page)
        get_image_url(String uri)
        get_image_html(String uri)
        get_image_data(String uri)
        list_similar(UUID image_id, UUID user_id)
    }
    class Note {
        UUID id
        destroy()
        read()
        create_with_sync(String text, UUID user_id)
        import(UUID id, String text, UUID user_id)
        update(String text)
        sync_typesense()
        sync_typesense_by_id(UUID note_id)
    }
    class ImageNote {
        UUID id
        destroy()
        create()
        read()
        import(UUID image_id, UUID note_id)
    }

    Image -- ImageNote
    Image -- Note
    ImageNote -- Note

```

```mermaid
classDiagram
    class Conversation {
        UUIDv7 id
        String title
        UtcDatetime archived_at
        UUID user_id
        Message[] messages
        User user
        read()
        destroy()
        create(String title)
        update(String title)
        generate_name()
        archive()
        my_conversations()
    }
    class Message {
        UUIDv7 id
        String text
        Source source
        UUID conversation_id
        UUID response_to_id
        Conversation conversation
        Message response_to
        Message response
        destroy()
        read()
        for_conversation(UUID conversation_id)
        create(UUID conversation_id, String text)
        respond()
        upsert_response(Boolean complete, String text, Map[] tool_calls, Map[] tool_results, ...)
    }

    User -- Conversation
    Conversation -- Message
    Message -- Message

```

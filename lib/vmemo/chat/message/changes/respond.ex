defmodule Vmemo.Chat.Message.Changes.Respond do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query

  import ReqLLM.Context

  alias Vmemo.Account
  alias Vmemo.Chat.AiRouter

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      message = changeset.data

      conversation =
        Ash.get!(Vmemo.Chat.Conversation, message.conversation_id,
          scope: context,
          load: [:kind, :image_id, :context_reset_at, :context_summary]
        )

      messages = conversation_messages(conversation, message, context)
      scoped_image_id = resolve_scoped_image_id(conversation, messages)

      case AiRouter.route_image_tool(
             conversation,
             message.text || "",
             context.actor,
             scoped_image_id
           ) do
        {:ok, result} ->
          upsert_final_response!(message, result.text, [], [], result.provider, result.tool_name)

          changeset

        :skip ->
          prompt_messages =
            build_prompt_messages(conversation, context.actor, messages, scoped_image_id)

          new_message_id = Ash.UUIDv7.generate()

          final_state =
            prompt_messages
            |> AshAi.ToolLoop.stream(
              otp_app: :vmemo,
              tools: [:image_search],
              model: resolve_model(),
              actor: context.actor,
              tenant: context.tenant,
              context: Map.new(Ash.Context.to_opts(context))
            )
            |> Enum.reduce(%{text: "", tool_calls: [], tool_results: [], stream_error: nil}, fn
              {:content, content}, acc ->
                if content not in [nil, ""] do
                  Vmemo.Chat.Message
                  |> Ash.Changeset.for_create(
                    :upsert_response,
                    %{
                      id: new_message_id,
                      response_to_id: message.id,
                      conversation_id: message.conversation_id,
                      text: content
                    },
                    actor: %AshAi{}
                  )
                  |> Ash.create!()
                end

                %{acc | text: acc.text <> (content || "")}

              {:tool_call, tool_call}, acc ->
                %{acc | tool_calls: append_event(acc.tool_calls, normalize_tool_call(tool_call))}

              {:tool_result, %{id: id, result: result}}, acc ->
                %{
                  acc
                  | tool_results:
                      append_event(acc.tool_results, normalize_tool_result(id, result))
                }

              {:error, reason}, acc ->
                %{acc | stream_error: reason}

              {:done, _}, acc ->
                acc

              _, acc ->
                acc
            end)

          stream_error_text = stream_error_text(final_state.stream_error)

          final_text =
            cond do
              stream_error_text && String.trim(final_state.text || "") != "" ->
                final_state.text <> "\n\n" <> stream_error_text

              stream_error_text ->
                stream_error_text

              String.trim(final_state.text || "") == "" &&
                  (final_state.tool_calls != [] || final_state.tool_results != []) ->
                "Completed tool call."

              true ->
                final_state.text
            end

          if final_state.stream_error ||
               final_state.tool_calls != [] ||
               final_state.tool_results != [] ||
               final_text != "" do
            upsert_final_response!(
              message,
              final_text,
              final_state.tool_calls,
              final_state.tool_results,
              "openrouter",
              nil,
              new_message_id
            )
          end

          changeset
      end
    end)
  end

  defp resolve_model do
    Application.fetch_env!(:vmemo, :openrouter_chat_model)
  end

  defp message_chain(messages) do
    Enum.map(messages, fn
      %{source: :agent, text: text} ->
        assistant(text || "")

      %{source: :user, text: text} ->
        user(text || "")
    end)
  end

  defp conversation_messages(conversation, message, context) do
    query =
      Vmemo.Chat.Message
      |> Ash.Query.filter(conversation_id == ^message.conversation_id)
      |> Ash.Query.filter(id != ^message.id)
      |> Ash.Query.select([
        :text,
        :source,
        :tool_calls,
        :tool_results,
        :tool_name,
        :attachments,
        :inserted_at
      ])
      |> Ash.Query.sort(inserted_at: :asc)

    query =
      if is_struct(conversation.context_reset_at, DateTime) do
        Ash.Query.filter(query, inserted_at > ^conversation.context_reset_at)
      else
        query
      end

    query
    |> Ash.read!(scope: context)
    |> Enum.concat([%{source: :user, text: message.text}])
  end

  defp build_prompt_messages(conversation, actor, messages, scoped_image_id) do
    language = actor_language(actor)
    convo_type = conversation.kind || "global"
    image_id = conversation.image_id
    effective_image_id = scoped_image_id || image_id
    context_summary = conversation.context_summary

    [
      system("""
      You are Vmemo's in-app assistant focused on this user's Vmemo content.
      Your job is to use the tools at your disposal to assist the user with Vmemo images and notes.
      Questions about the currently loaded image are in-scope, even if the user doesn't explicitly mention Vmemo.
      When you provide image URLs, always render them using Markdown image syntax: ![alt](url).
      Do not use normal Markdown links for images.
      If a user asks clearly unrelated general-purpose questions, do not answer the off-topic request.
      Instead, briefly explain this assistant is limited to Vmemo content and recommend using ChatGPT, Grok, or similar general-purpose assistants for those questions.
      Default response language: #{language}.
      Conversation type: #{convo_type}.
      Initial image id: #{image_id || "none"}.
      Effective image id: #{effective_image_id || "none"}.
      #{if is_binary(context_summary) and String.trim(context_summary) != "", do: "Context summary: " <> context_summary, else: ""}
      #{if is_binary(effective_image_id), do: AiRouter.tool_hint(), else: ""}
      """)
    ] ++ message_chain(messages)
  end

  defp resolve_scoped_image_id(conversation, _messages) when is_binary(conversation.image_id) do
    conversation.image_id
  end

  defp resolve_scoped_image_id(_conversation, messages) when is_list(messages) do
    messages
    |> Enum.reverse()
    |> Enum.find_value(fn message ->
      if Map.get(message, :tool_name) == "image_context" do
        message
        |> Map.get(:attachments, [])
        |> List.wrap()
        |> Enum.find_value(fn attachment ->
          Map.get(attachment, :id) || Map.get(attachment, "id")
        end)
      end
    end)
    |> case do
      id when is_binary(id) -> id
      id when is_nil(id) -> nil
      id -> to_string(id)
    end
  end

  defp resolve_scoped_image_id(_, _), do: nil

  defp actor_language(nil), do: "en"

  defp actor_language(actor) do
    case Account.get_user_profile_by_user_id(actor.id) do
      %{language: language} when is_binary(language) and language != "" -> language
      _ -> "en"
    end
  end

  defp append_event(items, value) when is_list(items), do: items ++ [value]
  defp append_event(_items, value), do: [value]

  defp normalize_tool_call(%{} = tool_call) do
    tool_call
    |> Map.new()
    |> Map.take([:id, :name, :arguments])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp normalize_tool_call(other), do: %{name: inspect(other)}

  defp normalize_tool_result(tool_call_id, {:ok, content, _raw}) do
    %{
      tool_call_id: tool_call_id,
      content: content,
      is_error: false
    }
  end

  defp normalize_tool_result(tool_call_id, {:error, content}) do
    %{
      tool_call_id: tool_call_id,
      content: content,
      is_error: true
    }
  end

  defp normalize_tool_result(tool_call_id, result) do
    %{
      tool_call_id: tool_call_id,
      content: inspect(result),
      is_error: false
    }
  end

  defp stream_error_text(nil), do: nil

  defp stream_error_text(:max_iterations_reached) do
    "I hit a response limit while generating this reply. Please try again."
  end

  defp stream_error_text(_reason) do
    "I hit an error while generating this response. Please try again."
  end

  defp upsert_final_response!(
         message,
         final_text,
         tool_calls,
         tool_results,
         provider,
         tool_name,
         message_id \\ nil
       ) do
    Vmemo.Chat.Message
    |> Ash.Changeset.for_create(
      :upsert_response,
      %{
        id: message_id || Ash.UUIDv7.generate(),
        response_to_id: message.id,
        conversation_id: message.conversation_id,
        complete: true,
        tool_calls: tool_calls,
        tool_results: tool_results,
        provider: provider,
        tool_name: tool_name,
        text: final_text
      },
      actor: %AshAi{}
    )
    |> Ash.create!()
  end
end

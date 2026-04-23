defmodule Vmemo.Chat.Message.Changes.Respond do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query

  import ReqLLM.Context

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      message = changeset.data

      messages =
        Vmemo.Chat.Message
        |> Ash.Query.filter(conversation_id == ^message.conversation_id)
        |> Ash.Query.filter(id != ^message.id)
        |> Ash.Query.select([:text, :source, :tool_calls, :tool_results])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!(scope: context)
        |> Enum.concat([%{source: :user, text: message.text}])

      prompt_messages =
        [
          system("""
          You are a helpful chat bot.
          Your job is to use the tools at your disposal to assist the user.
          When you provide image URLs, always render them using Markdown image syntax: ![alt](url).
          Do not use normal Markdown links for images.
          """)
        ] ++ message_chain(messages)

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
              | tool_results: append_event(acc.tool_results, normalize_tool_result(id, result))
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
        Vmemo.Chat.Message
        |> Ash.Changeset.for_create(
          :upsert_response,
          %{
            id: new_message_id,
            response_to_id: message.id,
            conversation_id: message.conversation_id,
            complete: true,
            tool_calls: final_state.tool_calls,
            tool_results: final_state.tool_results,
            text: final_text
          },
          actor: %AshAi{}
        )
        |> Ash.create!()
      end

      changeset
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
end

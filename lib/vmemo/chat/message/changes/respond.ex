defmodule Vmemo.Chat.Message.Changes.Respond do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query

  alias LangChain.Chains.LLMChain
  alias Vmemo.Chat.OpenRouterChatModel

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
        |> Ash.read!()
        |> Enum.concat([%{source: :user, text: message.text}])

      system_prompt =
        LangChain.Message.new_system!("""
        You are a helpful chat bot.
        Your job is to use the tools at your disposal to assist the user.
        When you provide image URLs, always render them using Markdown image syntax: ![alt](url).
        Do not use normal Markdown links for images.
        """)

      message_chain = message_chain(messages)

      new_message_id = Ash.UUIDv7.generate()

      %{
        llm: OpenRouterChatModel.new!(stream: false),
        custom_context: Map.new(Ash.Context.to_opts(context))
      }
      |> LLMChain.new!()
      |> LLMChain.add_message(system_prompt)
      |> LLMChain.add_messages(message_chain)
      # add the names of tools you want available in your conversation here.
      # i.e tools: [:lookup_weather]
      |> AshAi.setup_ash_ai(otp_app: :vmemo, tools: [:image_search], actor: context.actor)
      |> patch_tool_schemas()
      |> LLMChain.add_callback(%{
        on_llm_new_delta: fn _chain, deltas ->
          deltas
          |> List.wrap()
          |> Enum.each(fn delta ->
            content = LangChain.MessageDelta.content_to_string(delta)

            if not is_nil(content) and content != "" do
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
          end)
        end,
        on_message_processed: fn _chain, data ->
          if (data.tool_calls && Enum.any?(data.tool_calls)) ||
               (data.tool_results && Enum.any?(data.tool_results)) ||
               LangChain.Message.ContentPart.content_to_string(data.content) not in [nil, ""] do
            Vmemo.Chat.Message
            |> Ash.Changeset.for_create(
              :upsert_response,
              %{
                id: new_message_id,
                response_to_id: message.id,
                conversation_id: message.conversation_id,
                complete: true,
                tool_calls:
                  data.tool_calls &&
                    Enum.map(
                      data.tool_calls,
                      &Map.take(&1, [:status, :type, :call_id, :name, :arguments, :index])
                    ),
                tool_results:
                  data.tool_results &&
                    Enum.map(
                      data.tool_results,
                      &Map.update(
                        Map.take(&1, [
                          :type,
                          :tool_call_id,
                          :name,
                          :content,
                          :display_text,
                          :is_error,
                          :options
                        ]),
                        :content,
                        nil,
                        fn content ->
                          LangChain.Message.ContentPart.content_to_string(content)
                        end
                      )
                    ),
                text: LangChain.Message.ContentPart.content_to_string(data.content) || ""
              },
              actor: %AshAi{}
            )
            |> Ash.create!()
          end
        end
      })
      |> then(fn chain ->
        try do
          case LLMChain.run(chain, mode: :while_needs_response) do
            {:ok, _updated_chain} ->
              :ok

            {:error, _chain, error} ->
              # Log error but don't fail the changeset
              require Logger
              Logger.error("Error running LLMChain: #{inspect(error)}")
              :ok
          end
        rescue
          e in CaseClauseError ->
            # Handle langchain bug where {:ok, []} is not handled
            require Logger
            Logger.error("LangChain CaseClauseError (likely {:ok, []}): #{inspect(e)}")
            :ok

          e ->
            require Logger
            Logger.error("Unexpected error in LLMChain.run: #{inspect(e)}")
            :ok
        end
      end)

      changeset
    end)
  end

  defp message_chain(messages) do
    Enum.flat_map(messages, fn
      %{source: :agent} = message ->
        langchain_message =
          LangChain.Message.new_assistant!(%{
            content: message.text,
            tool_calls:
              message.tool_calls &&
                Enum.map(
                  message.tool_calls,
                  &LangChain.Message.ToolCall.new!(
                    Map.take(&1, ["status", "type", "call_id", "name", "arguments", "index"])
                  )
                )
          })

        if message.tool_results && !Enum.empty?(message.tool_results) do
          # Filter and map tool_results, ensuring tool_call_id exists
          valid_tool_results =
            message.tool_results
            |> Enum.filter(fn tr ->
              tool_call_id = Map.get(tr, "tool_call_id") || Map.get(tr, :tool_call_id)
              not is_nil(tool_call_id) && tool_call_id != ""
            end)
            |> Enum.map(fn tr ->
              # Normalize keys (handle both string and atom keys)
              tr
              |> Map.new(fn
                {k, v} when is_atom(k) -> {to_string(k), v}
                {k, v} -> {k, v}
              end)
              |> Map.take([
                "type",
                "tool_call_id",
                "name",
                "content",
                "display_text",
                "is_error",
                "options"
              ])
            end)

          if Enum.empty?(valid_tool_results) do
            [langchain_message]
          else
            [
              langchain_message,
              LangChain.Message.new_tool_result!(%{
                tool_results: Enum.map(valid_tool_results, &LangChain.Message.ToolResult.new!/1)
              })
            ]
          end
        else
          [langchain_message]
        end

      %{source: :user, text: text} ->
        [LangChain.Message.new_user!(text)]
    end)
  end

  # Patch tool schemas to add additionalProperties: false for Azure OpenAI compatibility
  defp patch_tool_schemas(chain) do
    case chain.tools do
      [_ | _] = tools ->
        patched_tools =
          Enum.map(tools, fn tool ->
            if tool.parameters_schema do
              patched_schema = patch_schema(tool.parameters_schema)
              struct(tool, parameters_schema: patched_schema)
            else
              tool
            end
          end)

        struct(chain, tools: patched_tools)

      _ ->
        chain
    end
  end

  defp patch_schema(%{"properties" => %{"input" => input_obj} = properties} = schema) do
    # Add additionalProperties: false to input object for Azure OpenAI compatibility
    # Azure OpenAI requires that required array includes all properties
    input_properties = Map.get(input_obj, "properties", %{})

    # Ensure all properties are in required array (Azure OpenAI requirement)
    all_required =
      input_properties
      |> Map.keys()
      |> Enum.uniq()

    patched_input =
      input_obj
      |> Map.put("additionalProperties", false)
      |> Map.put("required", all_required)

    patched_properties = Map.put(properties, "input", patched_input)
    Map.put(schema, "properties", patched_properties)
  end

  defp patch_schema(schema), do: schema
end

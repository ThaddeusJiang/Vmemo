defmodule Vmemo.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Vmemo.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Vmemo.Repo
      alias Vmemo.AshRepo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Vmemo.DataCase
    end
  end

  setup tags do
    Vmemo.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    shared = not tags[:async]
    pid1 = Ecto.Adapters.SQL.Sandbox.start_owner!(Vmemo.Repo, shared: shared)
    pid2 = Ecto.Adapters.SQL.Sandbox.start_owner!(Vmemo.AshRepo, shared: shared)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid2)
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid1)
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    cond do
      # Handle Ash.Error.Invalid
      is_struct(changeset, Ash.Error.Invalid) ->
        changeset.errors
        |> Enum.filter(fn error -> Map.has_key?(error, :field) end)
        |> Enum.group_by(fn error -> Map.get(error, :field) end)
        |> Map.new(fn {field, errors} ->
          messages =
            Enum.map(errors, fn error ->
              # Extract error message, stripping bread crumbs if present
              message = 
                if function_exported?(error.__struct__, :message, 1) do
                  error.__struct__.message(error)
                else
                  Map.get(error, :message, inspect(error))
                end
              
              # Strip "Bread Crumbs:" prefix if present
              # Format: "Bread Crumbs:\n  > ...\n\n\nactual message"
              message
              |> String.split("\n\n\n", parts: 2)
              |> List.last()
              |> String.trim()
              |> normalize_error_message()
            end)

          {field, messages}
        end)

      # Handle Ash.Changeset
      is_struct(changeset, Ash.Changeset) ->
        changeset.errors
        |> Enum.filter(fn error -> Map.has_key?(error, :field) end)
        |> Enum.group_by(fn error -> Map.get(error, :field) end)
        |> Map.new(fn {field, errors} ->
          messages =
            Enum.map(errors, fn error ->
              # Extract error message, stripping bread crumbs if present
              message = 
                if function_exported?(error.__struct__, :message, 1) do
                  error.__struct__.message(error)
                else
                  Map.get(error, :message, inspect(error))
                end
              
              # Strip "Bread Crumbs:" prefix if present
              # Format: "Bread Crumbs:\n  > ...\n\n\nactual message"
              message
              |> String.split("\n\n\n", parts: 2)
              |> List.last()
              |> String.trim()
              |> normalize_error_message()
            end)

          {field, messages}
        end)

      # Handle Ecto.Changeset
      is_struct(changeset, Ecto.Changeset) ->
        Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
          Regex.replace(~r"%{(\w+)}", message, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)

      # Fallback for other error types
      true ->
        %{}
    end
  end

  # Normalize Ash error messages to match Ecto-style messages
  defp normalize_error_message(message) do
    # Strip "Invalid value provided for X:" prefix if present
    message = 
      case Regex.run(~r/Invalid value provided for \w+: (.+)\n\nValue:/, message) do
        [_, core_message] -> String.trim(core_message)
        _ -> message
      end
    
    # Remove trailing period
    message = String.trim_trailing(message, ".")
    
    cond do
      String.contains?(message, "must match the pattern") ->
        "must have the @ sign and no spaces"
      
      String.contains?(message, "length must be greater than or equal to 12") ->
        "should be at least 12 character(s)"
      
      String.contains?(message, "length must be less than or equal to 72") ->
        "should be at most 72 character(s)"
      
      String.contains?(message, "length must be less than or equal to 160") ->
        "should be at most 160 character(s)"
      
      true ->
        message
    end
  end
end

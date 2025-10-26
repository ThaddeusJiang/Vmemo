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
      alias Vmemo.AshRepo

      # Ash changesets are based on Ecto changesets internally
      import Ecto.Changeset, only: [get_change: 2, get_field: 2]
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
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Vmemo.AshRepo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    # Ash changesets have a different error structure
    case changeset do
      %Ash.Changeset{errors: errors} ->
        errors
        |> Enum.flat_map(fn
          {field, error} -> [{field, Ash.ErrorKind.message(error)}]
          error when is_struct(error, Ash.Error) -> [{error.field || :base, Ash.ErrorKind.message(error)}]
          _ -> []
        end)
        |> Map.new()

      # For Ecto-style changesets (if still used)
      %Ecto.Changeset{errors: _errors} ->
        Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
          Regex.replace(~r"%{(\w+)}", message, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)

      _ ->
        %{}
    end
  end
end

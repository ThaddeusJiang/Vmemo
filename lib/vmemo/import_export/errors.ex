defmodule Vmemo.ImportExport.Errors do
  @moduledoc false

  def append_errors(errors, more) when is_list(more), do: errors ++ more
  def append_errors(errors, _more), do: errors

  def add_error(errors, _error, limit) when length(errors) >= limit, do: errors
  def add_error(errors, error, _limit), do: errors ++ [error]

  def format_error(error) when is_binary(error), do: error
  def format_error(error), do: inspect(error)
end

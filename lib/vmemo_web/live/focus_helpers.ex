defmodule VmemoWeb.Live.FocusHelpers do
  @moduledoc """
  Helper functions for focusing elements on the client side using ID selectors
  """

  @doc """
  Focuses an element by ID selector with optional delay and select_all option

  ## Examples

      socket |> focus("#my-input")
      socket |> focus("#email", delay: 200)
      socket |> focus("#note", select_all: true)

  ## Options

  - `:delay` - Delay in milliseconds before focusing (default: 100)
  - `:select_all` - Whether to select all text in the element (default: false)

  Note: The selector must be an ID selector starting with '#'
  """
  def focus(socket, id_selector, opts \\ []) when is_binary(id_selector) do
    unless String.starts_with?(id_selector, "#") do
      raise ArgumentError, "focus/3 only accepts ID selectors starting with '#', got: #{inspect(id_selector)}"
    end

    delay = Keyword.get(opts, :delay, 100)
    select_all = Keyword.get(opts, :select_all, false)

    Phoenix.LiveView.push_event(socket, "focus", %{
      selector: id_selector,
      delay: delay,
      select_all: select_all
    })
  end
end

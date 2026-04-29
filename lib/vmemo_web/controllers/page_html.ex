defmodule VmemoWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use VmemoWeb, :html
  use Gettext, backend: VmemoWeb.Gettext

  embed_templates "page_html/*"
end

defmodule VmemoWeb.LiveComponents.MarkdownContent do
  @moduledoc false
  use VmemoWeb, :live_component

  @impl true
  def update(assigns, socket) do
    html = render_markdown(assigns.text)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:processed_html, Phoenix.HTML.raw(html))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"markdown-content-#{@id}"}>
      {@processed_html}
    </div>
    """
  end

  defp render_markdown(text) do
    MDEx.to_html(text,
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        github_pre_lang: true,
        unsafe: true
      ],
      sanitize: MDEx.Document.default_sanitize_options()
    )
    |> case do
      {:ok, html} -> html
      {:error, _} -> text
    end
  end
end

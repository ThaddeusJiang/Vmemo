defmodule VmemoWeb.Live.UiPlayground do
  @moduledoc false
  use VmemoWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="page-shell">
      <div class="content-shell content-shell-tight">
        <h1 class="section-title text-2xl">UI Playground</h1>

        <div class="flex flex-col space-y-2 justify-start mt-4">
          <h2 class="text-sm uppercase tracking-[0.16em] text-base-content/65">Buttons</h2>

          <.button>
            save
          </.button>

          <.button variant="ghost">
            cancel button
          </.button>

          <.button variant="outline">
            outline button
          </.button>

          <.button disabled>
            disabled button
          </.button>

          <.button variant="danger">
            danger button
          </.button>
        </div>
      </div>
    </div>
    """
  end
end

defmodule VmemoWeb.Live.UiPlayground do
  use VmemoWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <h1>Hello, LiveView!</h1>

      <div class="flex flex-col space-y-2 justify-start">
        <h1>buttons</h1>

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
    """
  end
end

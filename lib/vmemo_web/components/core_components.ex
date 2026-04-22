defmodule VmemoWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: VmemoWeb.Gettext

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true
  slot :footer
  slot :header

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class={if @show, do: "relative z-50", else: "relative z-50 hidden"}
      data-show={@show}
    >
      <div
        id={"#{@id}-bg"}
        class="bg-zinc-800/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 "
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="h-full max-h-screen flex items-center justify-center">
          <div class="w-full max-w-prose h-full max-h-screen p-6 lg:p-6 ">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="h-full max-h-max bg-base-100 rounded-box shadow-lg p-4 sm:p-4 relative transition"
            >
              <.button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                variant="ghost"
                class="absolute btn-circle top-2 right-2"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark-solid" class="h-4 w-4" />
              </.button>

              <div id={"#{@id}-content"} class="h-full max-h-max flex flex-col">
                <header :if={@header != []} class="flex-none">
                  {render_slot(@header)}
                </header>

                <div class="h-full overflow-y-auto max-h-max grow mt-4">
                  {render_slot(@inner_block)}
                </div>

                <footer :if={@footer} class="flex justify-center gap-4 flex-none mt-4">
                  {render_slot(@footer)}
                </footer>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :class, :string, default: nil, doc: "custom classes for flash container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "alert w-80 sm:w-96 z-50",
        @class,
        @kind == :info && "alert-success",
        @kind == :error && "alert-error"
      ]}
      phx-hook="Toast"
      {@rest}
    >
      <div :if={@title} class="flex items-center gap-2">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <span class="font-semibold">{@title}</span>
      </div>
      <div class="text-sm">{msg}</div>
      <button
        type="button"
        class="btn btn-circle btn-ghost btn-sm [--btn-color:transparent]"
        aria-label={gettext("close")}
      >
        <.icon name="hero-x-mark-solid" class="h-4 w-4" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"
  attr :class, :string, default: nil, doc: "custom classes passed to flash items"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash
        kind={:info}
        title={gettext("Success!")}
        flash={@flash}
        class={@class}
      />
      <.flash
        kind={:error}
        title={gettext("Error!")}
        flash={@flash}
        class={@class}
      />
      <%!-- <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-2 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-2 h-3 w-3 animate-spin" />
      </.flash> --%>
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-3">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="pt-2 flex items-center justify-end gap-2">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Save</.button>
      <.button variant="ghost">Cancel</.button>
      <.button variant="danger">Delete</.button>
      <.button variant="outline">Star</.button>
      <.button size="sm">Small</.button>
      <.button size="lg">Large</.button>

      <.button phx-click="go" class="ml-2">Send!</.button>

  """
  attr :variant, :string, default: "submit", values: ~w(submit ghost danger outline)
  attr :size, :string, default: nil, values: [nil | ~w(xs sm lg)]
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value type  )

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      class={[
        "btn",
        @size == "xs" && "btn-xs",
        @size == "sm" && "btn-sm",
        @size == "lg" && "btn-lg",
        @size == nil && "py-2",
        "phx-submit-loading:opacity-75 phx-submit-loading:cursor-wait phx-submit-loading:disabled",
        @variant == "submit" && "btn-neutral",
        @variant == "ghost" && "btn-ghost",
        @variant == "danger" && "btn-error",
        @variant == "outline" && "btn-outline",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="form-control">
      <label class="label cursor-pointer">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="checkbox"
          {@rest}
        />
        <span class="label-text">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>
        <span class="label-text-alt text-error">{msg}</span>
      </.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="form-control w-full">
      <div class="space-y-1">
        <.label for={@id} class="label-text">{@label}</.label>
        <select
          id={@id}
          name={@name}
          class="select select-bordered w-full rounded-lg"
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </div>
      <.error :for={msg <- @errors}>
        <span class="label-text-alt text-error">{msg}</span>
      </.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="form-control w-full">
      <div class="space-y-1">
        <.label for={@id} class="label-text">{@label}</.label>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            "input input-bordered w-full rounded-lg",
            @errors != [] && "input-error"
          ]}
          autocomplete={get_autocomplete_value(@type, @name)}
          {@rest}
        />
      </div>
      <.error :for={msg <- @errors}>
        {msg}
      </.error>
    </div>
    """
  end

  # Helper function to set appropriate autocomplete values
  defp get_autocomplete_value(type, _name) when type == "email", do: "email"

  defp get_autocomplete_value(type, name) when type == "password" do
    case name do
      "current_password" -> "current-password"
      _ -> "new-password"
    end
  end

  defp get_autocomplete_value(_type, _name), do: nil

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: nil

  attr :label, :string, required: true
  attr :errors, :list, default: []

  attr :rest, :global

  def textarea_field(assigns) do
    ~H"""
    <div class="form-control w-full">
      <div class="space-y-1">
        <.label for={@id} class="label-text">{@label}</.label>
        <.textarea id={@id} name={@name} value={@value} {@rest} />
      </div>
      <.error :for={msg <- @errors}>
        <span class="label-text-alt text-error">{msg}</span>
      </.error>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :class, :string, default: nil

  attr :rest, :global

  def textarea(assigns) do
    ~H"""
    <textarea
      id={@id}
      name={@name}
      class={[
        "textarea textarea-bordered w-full rounded-lg",
        @class
      ]}
      {@rest}
    >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={["label", @class]}>
      <span class="label-text">{render_slot(@inner_block)}</span>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <div class="label">
      <span class="label-text-alt text-error">{render_slot(@inner_block)}</span>
    </div>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      "text-center mt-4 mb-6",
      @actions != [] && "flex items-center justify-between gap-6",
      @class
    ]}>
      <div>
        <h1 class="text-2xl font-bold ">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-zebra w-full">
        <thead>
          <tr>
            <th :for={col <- @col}>{col[:label]}</th>
            <th :if={@action != []}>
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={[@row_click && "hover:bg-base-300 cursor-pointer"]}
            phx-click={@row_click && @row_click.(row)}
          >
            <td :for={{col, i} <- Enum.with_index(@col)}>
              <span class={[i == 0 && "font-semibold"]}>
                {render_slot(col, @row_item.(row))}
              </span>
            </td>
            <td :if={@action != []} class="text-right">
              <div class="flex justify-end gap-2">
                <span :for={action <- @action}>
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-6">
      <dl class="-my-4 divide-y divide-zinc-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-6">
          <dt class="w-1/4 flex-none text-zinc-500">{item.title}</dt>
          <dd class="text-zinc-700">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Formats a datetime to display in the current timezone.

  ## Examples

      <.format_datetime datetime={~U[2023-01-01 12:00:00Z]} />
      <.format_datetime datetime={~U[2023-01-01 12:00:00Z]} format="date" />
      <.format_datetime datetime={~U[2023-01-01 12:00:00Z]} format="datetime" />
  """
  attr :datetime, :any, required: true, doc: "The datetime to format"

  attr :format, :string,
    default: "datetime",
    doc: "Format: 'date', 'time', 'datetime', or custom format string"

  attr :class, :string, default: nil

  def format_datetime(assigns) do
    assigns =
      assign(
        assigns,
        :formatted,
        case assigns.format do
          "date" -> format_to_local_date(assigns.datetime)
          "time" -> format_to_local_time(assigns.datetime)
          "datetime" -> format_to_local_datetime(assigns.datetime)
          custom_format -> format_to_local_custom(assigns.datetime, custom_format)
        end
      )

    ~H"""
    <span class={@class}>{@formatted}</span>
    """
  end

  # Helper functions for datetime formatting
  defp format_to_local_date(datetime) when not is_nil(datetime) do
    # Convert UTC time to China timezone (UTC+8)
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d")
  end

  defp format_to_local_date(_), do: ""

  defp format_to_local_time(datetime) when not is_nil(datetime) do
    # Convert UTC time to China timezone (UTC+8)
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%H:%M:%S")
  end

  defp format_to_local_time(_), do: ""

  defp format_to_local_datetime(datetime) when not is_nil(datetime) do
    # Convert UTC time to China timezone (UTC+8)
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d %H:%M")
  end

  defp format_to_local_datetime(_), do: ""

  defp format_to_local_custom(datetime, format) when not is_nil(datetime) do
    # Convert UTC time to China timezone (UTC+8)
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, format)
  end

  defp format_to_local_custom(_, _), do: ""

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-6">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" /> {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-2 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def generate_id(length \\ 16) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode16(case: :lower)
    |> binary_part(0, length)
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(VmemoWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(VmemoWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :class, :string, default: nil
  attr :wrapper_class, :string, default: nil
  attr :id, :string, default: nil
  # arbitrary HTML attributes
  attr :rest, :global, include: ~w(loading decoding fetchpriority referrerpolicy)

  @doc """
  Renders an image tag.

  ## Examples

      <.img src="/images/image.jpg" alt="A image of a mountain" />
  """
  def img(assigns) do
    ~H"""
    <span class={["img-fallback-wrap block relative rounded-lg overflow-hidden", @wrapper_class]}>
      <img
        src={@src}
        alt={@alt}
        class={[
          "w-full h-auto object-cover rounded-lg shadow hover:shadow-lg hover:transition-transform",
          @class
        ]}
        id={@id || generate_id()}
        phx-hook="ImageLoader"
        {@rest}
      />
      <span class="img-fallback-overlay" aria-hidden="true">
        <.icon name="hero-photo" class="size-8" />
      </span>
    </span>
    """
  end

  @doc """
  Not found UI component.

  ## Examples

      <.not_found />
  """
  def not_found(assigns) do
    ~H"""
    <div class="hero grow">
      <div class="hero-content text-center">
        <div class="max-w-md">
          <img src="/images/undraw_taken.svg" alt="not found" class="w-60 h-60 mx-auto" />
          <h1 class="text-5xl font-bold">Page not found</h1>
          <p class="py-4">
            Sorry, we couldn't find the page you're looking for.
          </p>
          <.link navigate="/" class="btn btn-neutral">
            <span aria-hidden="true">&larr;</span> Back to home
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :note, :string, required: true

  @doc """
  Renders image with note.
  """
  def photo_note(assigns) do
    ~H"""
    <div class="card max-w-md mx-auto bg-base-100 shadow-xl rounded-3xl">
      <figure>
        <img
          src={@src}
          alt={@alt}
          class="w-full h-auto object-cover"
        />
      </figure>
      <div class="card-body">
        <h2 class="card-title">Note</h2>
        <p class="text-base-content/70">
          {@note}
        </p>
      </div>
    </div>
    """
  end
end

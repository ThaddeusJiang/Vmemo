defmodule VmemoWeb.AdminLoginLive do
  use VmemoWeb, :live_view

  on_mount {VmemoWeb.AdminAuth, :redirect_if_admin_is_authenticated}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: :admin))}
  end

  def handle_event("validate", %{"admin" => admin_params}, socket) do
    form = to_form(admin_params, as: :admin)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"admin" => _admin_params}, socket) do
    # 这里不需要验证，直接提交到控制器处理
    # 因为 token 验证在控制器中进行
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8">
        <div>
          <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
            管理员登录
          </h2>
          <p class="mt-2 text-center text-sm text-gray-600">
            请输入管理员 token 以访问管理后台
          </p>
        </div>

        <.form for={@form} id="admin-login-form" phx-change="validate" phx-submit="save" action={~p"/admin/login"} method="post" class="mt-8 space-y-6">
          <div>
            <.input
              field={@form[:token]}
              type="password"
              label="管理员 Token"
              placeholder="请输入管理员 token"
              required
              class="appearance-none rounded-lg relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
            />
          </div>

          <div>
            <button
              type="submit"
              class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-lg text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors duration-200"
            >
              登录
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end

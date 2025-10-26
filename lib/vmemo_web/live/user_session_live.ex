defmodule VmemoWeb.UserSessionLive do
  use VmemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: :user)}
  end


  def handle_event("sign_out", _params, socket) do
    socket =
      socket
      |> put_flash(:info, "Signed out successfully")
      |> redirect(to: ~p"/")

    {:noreply, socket}
  end


  def render(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen">
      <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-md w-full space-y-8">
          <div>
            <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
              Sign in to your account
            </h2>
          </div>
          <form action={~p"/users/log_in"} method="post" class="mt-8 space-y-6">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <div class="rounded-md shadow-sm -space-y-px">
              <div>
                <label for="user_email" class="sr-only">Email address</label>
                <input
                  id="user_email"
                  name="user[email]"
                  type="email"
                  autocomplete="email"
                  required
                  class="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                  placeholder="Email address"
                />
              </div>
              <div>
                <label for="user_password" class="sr-only">Password</label>
                <input
                  id="user_password"
                  name="user[password]"
                  type="password"
                  autocomplete="current-password"
                  required
                  class="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                  placeholder="Password"
                />
              </div>
            </div>

            <div>
              <button
                type="submit"
                class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Sign in
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end

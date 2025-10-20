defmodule Vmemo.Account.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends password reset emails for Ash Authentication
  """
  use AshAuthentication.Sender
  alias Vmemo.Account.UserNotifier

  @impl true
  def send(user, token, _opts) do
    url = "#{VmemoWeb.Endpoint.url()}/password-reset/#{token}"
    UserNotifier.deliver_reset_password_instructions(user, url)
  end
end

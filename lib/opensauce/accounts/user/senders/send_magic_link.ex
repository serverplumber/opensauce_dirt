defmodule OpenSauce.Accounts.User.Senders.SendMagicLink do
  @moduledoc false
  use AshAuthentication.Sender

  require Logger

  @impl AshAuthentication.Sender
  def send(_user, token, _opts) do
    url = OpenSauceWeb.Endpoint.url() <> "/auth/user/magic_link?token=#{token}"

    Logger.warning("""

    ┌─ MAGIC LINK ──────────────────────────────────────────────────┐
    │  #{url}
    └───────────────────────────────────────────────────────────────┘
    """)
  end
end

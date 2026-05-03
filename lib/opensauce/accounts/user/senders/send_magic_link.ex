defmodule OpenSauce.Accounts.User.Senders.SendMagicLink do
  @moduledoc false
  use AshAuthentication.Sender

  @impl AshAuthentication.Sender
  def send(_user, token, _opts) do
    url = OpenSauceWeb.Endpoint.url() <> "/auth/user/magic_link?token=#{token}"

    IO.puts("""

    ┌─ MAGIC LINK ──────────────────────────────────────────────────┐
    │  #{url}
    └───────────────────────────────────────────────────────────────┘
    """)
  end
end

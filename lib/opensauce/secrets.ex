defmodule OpenSauce.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], OpenSauce.Accounts.User, _opts, _context) do
    Application.fetch_env(:opensauce, :token_signing_secret)
  end
end

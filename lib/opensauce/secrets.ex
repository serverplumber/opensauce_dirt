# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], OpenSauce.Accounts.User, _opts, _context) do
    Application.fetch_env(:opensauce, :token_signing_secret)
  end
end

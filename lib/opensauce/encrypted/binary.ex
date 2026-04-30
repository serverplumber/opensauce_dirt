defmodule OpenSauce.Encrypted.Binary do
  @moduledoc false
  use Cloak.Ecto.Binary, vault: OpenSauce.Vault
end

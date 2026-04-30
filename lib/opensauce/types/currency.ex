defmodule OpenSauce.Types.Currency do
  @moduledoc false
  use Ash.Type.Enum, values: [:EUR, :CAD, :USD]
end

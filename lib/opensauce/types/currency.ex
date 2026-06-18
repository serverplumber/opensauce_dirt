# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Types.Currency do
  @moduledoc false
  use Ash.Type.Enum, values: [:EUR, :CAD, :USD]
end

# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Inventory.PurchaseOrder.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:draft, :ordered, :confirmed, :received]
end

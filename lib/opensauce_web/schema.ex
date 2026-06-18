# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.Schema do
  @moduledoc false
  use Absinthe.Schema

  use AshGraphql,
    domains: [
      OpenSauce.Work,
      OpenSauce.Inventory,
      OpenSauce.CRM
    ]

  query do
  end

  mutation do
  end
end

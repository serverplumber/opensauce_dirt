# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.JsonApiRouter do
  @moduledoc false
  use AshJsonApi.Router,
    domains: [
      OpenSauce.Work,
      OpenSauce.Inventory,
      OpenSauce.CRM
    ],
    open_api: "/open_api"
end

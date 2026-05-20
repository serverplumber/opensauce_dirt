defmodule OpenSauceWeb.JsonApiRouter do
  @moduledoc false
  use AshJsonApi.Router,
    domains: [
      OpenSauce.Orders,
      OpenSauce.Inventory,
      OpenSauce.CRM,
      OpenSauce.Settings
    ],
    open_api: "/open_api"
end

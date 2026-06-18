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

defmodule OpenSauceWeb.Schema do
  @moduledoc false
  use Absinthe.Schema

  use AshGraphql,
    domains: [
      OpenSauce.Orders,
      OpenSauce.Inventory,
      OpenSauce.CRM
    ]

  query do
  end

  mutation do
  end
end

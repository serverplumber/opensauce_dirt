defmodule OpenSauce.CRM do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  json_api do
    prefix "/api/json"
  end

  graphql do
  end

  resources do
    resource OpenSauce.CRM.Address do
      define :create_address, action: :create
      define :update_address, action: :update
      define :destroy_address, action: :destroy
    end

    resource OpenSauce.CRM.Customer do
      define :get_customer_by_id, action: :read, get_by: [:id]
      define :get_customer_by_reference, action: :read, get_by: [:reference]
      define :get_customer_by_email, args: [:email], action: :get_by_email
      define :list_customers, action: :list
      define :list_customers_with_keyset, action: :keyset
      define :destroy_customer, action: :destroy
    end

    resource OpenSauce.CRM.EngagementMaterial do
      define :list_engagement_materials, action: :read
      define :create_engagement_material, action: :create
      define :destroy_engagement_material, action: :destroy
    end

    resource OpenSauce.CRM.Engagement do
      define :get_engagement_by_id, action: :read, get_by: [:id]
      define :list_engagements, action: :read
      define :create_engagement, action: :create
      define :update_engagement, action: :update
      define :sign_engagement, action: :sign
      define :destroy_engagement, action: :destroy
    end
  end
end

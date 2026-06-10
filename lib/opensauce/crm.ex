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
      define :list_gardens, action: :list_gardens
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

    resource OpenSauce.CRM.EngagementImage do
      define :create_engagement_image, action: :create
      define :update_engagement_image, action: :update
      define :destroy_engagement_image, action: :destroy
      define :list_engagement_images, action: :for_engagement, args: [:engagement_id]
      define :list_engagement_paintings, action: :paintings_for_engagement, args: [:engagement_id]
    end

    resource OpenSauce.CRM.EngagementMaterial do
      define :list_engagement_materials, action: :read
      define :create_engagement_material, action: :create
      define :update_engagement_material, action: :update
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

    resource OpenSauce.CRM.Invoice do
      define :get_invoice_by_id, action: :read, get_by: [:id]
      define :list_invoices, action: :read
      define :create_invoice, action: :create
      define :update_invoice, action: :update
      define :mark_invoice_paid, action: :mark_paid
      define :mark_invoice_sent, action: :mark_sent
      define :destroy_invoice, action: :destroy
    end
  end
end

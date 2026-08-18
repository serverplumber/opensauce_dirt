# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

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
      define :list_customers, action: :list
      define :list_customers_with_keyset, action: :keyset
      define :list_customers_with_uninvoiced_jobs, action: :with_uninvoiced_jobs
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
      define :search_engagements, action: :search, args: [:query]
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
      define :void_invoice, action: :void
      define :destroy_invoice, action: :destroy
    end
  end
end

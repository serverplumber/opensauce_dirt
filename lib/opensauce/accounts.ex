# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource OpenSauce.Accounts.Organisation do
      define :create_organisation, action: :create
      define :list_organisations, action: :read
      define :get_organisation, action: :read, get_by: [:id]
      define :get_organisation_by_slug, action: :read, get_by: [:slug]
      define :update_organisation, action: :update
      define :delete_organisation, action: :destroy
    end

    resource OpenSauce.Accounts.OrganisationMember do
      define :create_organisation_member, action: :create
      define :list_organisation_members, action: :read
      define :list_memberships_for_user, action: :list_for_user, args: [:user_id]
      define :list_members_for_organisation, action: :list_for_organisation, args: [:organisation_id]
      define :get_member_by_user_and_organisation, action: :get_by_user_and_organisation, args: [:user_id, :organisation_id]
      define :update_organisation_member, action: :update
      define :suspend_organisation_member, action: :suspend
      define :activate_organisation_member, action: :activate
      define :delete_organisation_member, action: :destroy
    end

    resource OpenSauce.Accounts.Token

    resource OpenSauce.Accounts.User do
      define :create_user, action: :create
      define :get_user_by_email, args: [:email], action: :get_by_email
      define :update_user, action: :update
    end

    resource OpenSauce.Accounts.ApiKey do
      define :create_api_key, action: :create
      define :list_api_keys_for_organisation, action: :list_for_organisation
      define :revoke_api_key, action: :revoke
      define :authenticate_api_key, action: :authenticate
      define :touch_api_key_last_used, action: :touch_last_used
      define :get_api_key_by_id, action: :read, get_by: [:id]
    end

    resource OpenSauce.Accounts.TaxRate do
      define :list_tax_rates, action: :list
      define :create_tax_rate, action: :create
      define :update_tax_rate, action: :update
      define :delete_tax_rate, action: :destroy
    end
  end
end

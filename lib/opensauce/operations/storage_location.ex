# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Operations.StorageLocation do
  @moduledoc false
  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      OpenSauce.Concerns.Multitenanted,
      OpenSauce.Concerns.Venued,
    ]

  postgres do
    table "operations_storage_locations"
    repo OpenSauce.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name, :venue_id, :organisation_id],
      update: [:name]
    ]

    read :list_for_venue do
      argument :venue_id, :uuid, allow_nil?: false
      filter expr(venue_id == ^arg(:venue_id))
    end
  end

  policies do
    policy always() do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end
end

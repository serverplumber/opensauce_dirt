# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

# seeds.exs

alias OpenSauce.Accounts

if System.get_env("SEED_DATA") == "true" or (Code.ensure_loaded?(Mix) and Mix.env() == :dev) do
  {:ok, demo_org} =
    Accounts.create_organisation(%{name: "Demo Bakery", slug: "demo-bakery"},
      authorize?: false,
      upsert?: true,
      upsert_identity: :unique_slug,
      upsert_fields: [:name]
    )

  seed_user = fn email, role ->
    {:ok, user} =
      Accounts.create_user(%{email: email},
        authorize?: false,
        upsert?: true,
        upsert_identity: :unique_email,
        upsert_fields: [:email]
      )

    {:ok, _} =
      Accounts.create_organisation_member(
        %{user_id: user.id, organisation_id: demo_org.id, role: role},
        authorize?: false,
        upsert?: true,
        upsert_identity: :unique_membership,
        upsert_fields: [:role]
      )

    user
  end

  seed_user.("admin@sauce", :owner)
  seed_user.("owner@sauce", :owner)
  seed_user.("staff@sauce", :staff)

  IO.puts("Done!")
else
  IO.puts("Seeds are only allowed in the dev environment.")
end

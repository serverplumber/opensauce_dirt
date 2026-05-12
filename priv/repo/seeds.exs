# seeds.exs

alias OpenSauce.Accounts
alias OpenSauce.Settings

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

  Ash.Seed.seed!(Settings.Settings, %{
    currency: :CAD,
    tax_mode: :exclusive,
    tax_rate: Decimal.new("0.13"),
    offers_pickup: true,
    offers_delivery: true,
    lead_time_days: 1,
    daily_capacity: 25,
    shipping_flat: Decimal.new("5.00"),
    labor_hourly_rate: Decimal.new("18.50"),
    labor_overhead_percent: Decimal.new("0.15"),
    retail_markup_mode: :percent,
    retail_markup_value: Decimal.new("35"),
    wholesale_markup_mode: :percent,
    wholesale_markup_value: Decimal.new("20"),
    organisation_id: demo_org.id
  })

  IO.puts("Done!")
else
  IO.puts("Seeds are only allowed in the dev environment.")
end

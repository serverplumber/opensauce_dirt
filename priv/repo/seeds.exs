# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

alias OpenSauce.Accounts
alias OpenSauce.CRM

if System.get_env("SEED_DATA") == "true" or (Code.ensure_loaded?(Mix) and Mix.env() == :dev) do
  # ── Organisation ────────────────────────────────────────────────────────────

  {:ok, demo_org} =
    Accounts.create_organisation(%{name: "Plants Plan Designs Inc.", slug: "demo-bakery"},
      authorize?: false,
      upsert?: true,
      upsert_identity: :unique_slug,
      upsert_fields: [:name]
    )

  {:ok, demo_org} =
    Accounts.update_organisation(demo_org, %{
      name: "Plants Plan Designs Inc.",
      legal_name: "1175829034 Québec Inc.",
      currency: :CAD,
      tax_mode: :exclusive,
      phone: "(514) 555-0192",
      website: "plantsplan.design",
      email_from_name: "Plants Plan Designs",
      payment_info: "Virement Interac : comptabilite@plantsplan.design\nChèque à l'ordre de Plants Plan Designs Inc.",
      invoice_terms:
        "Tout solde impayé porte intérêt à compter du 31e jour suivant la date de facturation, au taux annuel de 24 %, composé quotidiennement."
    }, authorize?: false)

  # ── Staff accounts ───────────────────────────────────────────────────────────

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

  # ── Tax rates ─────────────────────────────────────────────────────────────────

  {:ok, _} =
    Accounts.create_tax_rate(
      %{
        name: "GST",
        rate: Decimal.new("5"),
        is_compound: false,
        position: 1,
        registration_number: "746 293 815 RT0001"
      },
      authorize?: false,
      tenant: demo_org.id
    )

  {:ok, _} =
    Accounts.create_tax_rate(
      %{
        name: "QST",
        rate: Decimal.new("9.975"),
        is_compound: false,
        position: 2,
        registration_number: "1012583947 TQ0001"
      },
      authorize?: false,
      tenant: demo_org.id
    )

  # ── Client 1: Sophie Tremblay — one garden ──────────────────────────────────

  sophie =
    CRM.Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: "Sophie",
      last_name: "Tremblay",
      email: "sophie.tremblay@example.com",
      phone: "(514) 555-0141",
      garden_addresses: [
        %{
          name: "Cour arrière",
          street: "4281 Avenue Laval",
          city: "Outremont",
          province: "QC",
          zip: "H2V 2K7",
          country: "Canada",
          is_garden: true,
          is_indoor: false,
          is_billing: false
        }
      ]
    })
    |> Ash.create!(authorize?: false, tenant: demo_org.id)
    |> Ash.load!(:garden_addresses, authorize?: false, tenant: demo_org.id)

  sophie_garden = List.first(sophie.garden_addresses)

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: sophie.id,
        garden_id: sophie_garden.id,
        scope_title: "Backyard Garden Design & Install",
        scope_description:
          "Full backyard redesign with raised perennial beds, stone pathways, and shade plantings under the existing maple.",
        status: :signed,
        install_price: Decimal.new("8500.00"),
        term_start: ~D[2026-05-01],
        term_end: ~D[2026-08-31]
      },
      authorize?: false,
      tenant: demo_org.id
    )

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: sophie.id,
        garden_id: sophie_garden.id,
        scope_title: "Annual Garden Maintenance",
        status: :in_progress,
        maintenance_price_annual: Decimal.new("2400.00"),
        term_start: ~D[2026-04-01],
        term_end: ~D[2027-11-30]
      },
      authorize?: false,
      tenant: demo_org.id
    )

  # ── Client 2: Marc Beauchamp — two gardens ──────────────────────────────────

  marc =
    CRM.Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: "Marc",
      last_name: "Beauchamp",
      email: "marc.beauchamp@example.com",
      phone: "(514) 555-0283",
      garden_addresses: [
        %{
          name: "Cour avant",
          street: "73 Rue Metcalfe",
          city: "Westmount",
          province: "QC",
          zip: "H3Z 2H2",
          country: "Canada",
          is_garden: true,
          is_indoor: false,
          is_billing: false
        }
      ]
    })
    |> Ash.create!(authorize?: false, tenant: demo_org.id)
    |> Ash.load!(:garden_addresses, authorize?: false, tenant: demo_org.id)

  marc_front = List.first(marc.garden_addresses)

  marc_back =
    CRM.Address
    |> Ash.Changeset.for_create(:create, %{
      customer_id: marc.id,
      name: "Cour arrière",
      street: "73 Rue Metcalfe",
      city: "Westmount",
      province: "QC",
      zip: "H3Z 2H2",
      country: "Canada",
      is_garden: true,
      is_indoor: false,
      is_billing: false
    })
    |> Ash.create!(authorize?: false, tenant: demo_org.id)

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: marc.id,
        garden_id: marc_front.id,
        scope_title: "Front Yard Planting",
        scope_description:
          "Low-maintenance ornamental planting with seasonal colour and hedging along the fence line.",
        status: :draft,
        install_price: Decimal.new("4200.00")
      },
      authorize?: false,
      tenant: demo_org.id
    )

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: marc.id,
        garden_id: marc_back.id,
        scope_title: "Backyard Landscaping",
        scope_description:
          "Full backyard redesign: lawn, perennial borders, terrace extension, and cedar pergola plantings.",
        status: :signed,
        install_price: Decimal.new("11000.00"),
        term_start: ~D[2026-06-01],
        term_end: ~D[2026-09-30]
      },
      authorize?: false,
      tenant: demo_org.id
    )

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: marc.id,
        garden_id: marc_front.id,
        scope_title: "Ongoing Garden Care",
        status: :in_progress,
        maintenance_price_annual: Decimal.new("3600.00"),
        term_start: ~D[2026-04-01],
        term_end: ~D[2027-11-30]
      },
      authorize?: false,
      tenant: demo_org.id
    )

  # ── Client 3: Isabelle Garneau — indoor + outdoor ───────────────────────────

  isabelle =
    CRM.Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: "Isabelle",
      last_name: "Garneau",
      email: "isabelle.garneau@example.com",
      phone: "(514) 555-0374",
      garden_addresses: [
        %{
          name: "Terrasse",
          street: "3412 Rue Saint-Denis",
          city: "Montréal",
          province: "QC",
          zip: "H2X 3L3",
          country: "Canada",
          is_garden: true,
          is_indoor: false,
          is_billing: false
        }
      ]
    })
    |> Ash.create!(authorize?: false, tenant: demo_org.id)
    |> Ash.load!(:garden_addresses, authorize?: false, tenant: demo_org.id)

  isa_terrace = List.first(isabelle.garden_addresses)

  isa_salon =
    CRM.Address
    |> Ash.Changeset.for_create(:create, %{
      customer_id: isabelle.id,
      name: "Salon",
      street: "3412 Rue Saint-Denis",
      city: "Montréal",
      province: "QC",
      zip: "H2X 3L3",
      country: "Canada",
      is_garden: false,
      is_indoor: true,
      is_billing: false
    })
    |> Ash.create!(authorize?: false, tenant: demo_org.id)

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: isabelle.id,
        garden_id: isa_terrace.id,
        scope_title: "Terrace Garden Design",
        scope_description:
          "Container garden for south-facing terrace: dwarf fruit trees, herbs, and flowering climbers on trellis.",
        status: :draft,
        install_price: Decimal.new("6800.00")
      },
      authorize?: false,
      tenant: demo_org.id
    )

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: isabelle.id,
        garden_id: isa_salon.id,
        scope_title: "Indoor Plant Collection",
        scope_description:
          "Curated indoor plant installation with bespoke planters, tropical foliage, and monthly care visits.",
        status: :signed,
        install_price: Decimal.new("1800.00"),
        maintenance_price_annual: Decimal.new("1200.00"),
        term_start: ~D[2026-03-01]
      },
      authorize?: false,
      tenant: demo_org.id
    )

  {:ok, _} =
    CRM.create_engagement(
      %{
        customer_id: isabelle.id,
        garden_id: isa_terrace.id,
        scope_title: "Terrace Seasonal Maintenance",
        status: :in_progress,
        maintenance_price_annual: Decimal.new("2800.00"),
        term_start: ~D[2026-04-01],
        term_end: ~D[2027-11-30]
      },
      authorize?: false,
      tenant: demo_org.id
    )

  IO.puts("Done!")
else
  IO.puts("Seeds are only allowed in the dev environment.")
end

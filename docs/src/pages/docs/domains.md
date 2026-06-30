---
layout: ../../layouts/DocsLayout.astro
title: Domain Architecture
---

# Domain Architecture

## Tenancy Model

Row-level multitenancy via `AshPostgres` (`:attribute` strategy).
All scoped resources carry `organisation_id`. The tenant boundary is always the **Organisation**.

### Unscoped (no `organisation_id`)

| Resource | Domain | Notes |
|---|---|---|
| `Organisation` | `Accounts` | The tenant account |
| `User` | `Accounts` | Identity only — email, auth state |
| `OrganisationMember` | `Accounts` | Join: user ↔ org; carries `role` and `labor_hourly_rate` |

`OrganisationMember.role` — `:owner | :manager | :staff | :readonly`

All other resources are org-scoped via the `OpenSauce.Concerns.Multitenanted` fragment.

---

## Domains & Resources

### `Accounts`

Unscoped bootstrap layer. Resolves tenant before any domain call.

- `Organisation` — name, slug, currency, tax mode, overhead percent, mileage rate, invoice config, logo keys
- `User` — email, magic-link auth
- `OrganisationMember` — role, `labor_hourly_rate`, status (`:active | :suspended`)
- `TaxRate` — name, rate, `is_compound`, `registration_number`, position (order matters for compound stacking)
- `ApiKey` — scoped API access tokens

### `CRM`

Client relationship and engagement lifecycle.

- `Customer` — type (`:individual | :company`), contact info, billing address
- `Address` — garden sites and billing addresses; flags `is_garden`, `is_indoor`, `is_billing`
- `Engagement` — scope title/description, `install_price`, `maintenance_price_annual`, status lifecycle, client `signature`
- `EngagementMaterial` — planned materials at quote time: `quantity`, `cost` (estimated supplier price), `price` (planned billable rate)
- `EngagementImage` — photos and paintings; `type: :painting` controls invoice description copy
- `Invoice` — `amount` (subtotal), `line_items` (array of maps), `snapshot` (frozen at send time), status lifecycle

Engagement status flow: `:draft → :proposed → :signed → :in_progress → :completed | :cancelled`

Invoice status flow: `:draft → :sent → :paid | :void`

### `Work`

Field job scheduling, crew logging, and cost realization.

- `Job` — type (`:client_work | :shift | :internal_work`), `service_category`, `scheduled_for`, `duration_estimate`, `realized_cost`
- `JobStaff` — tentative crew assignments; drives calendar and cost estimation
- `JobEvent` — append-only log of field events (arrival, departure, shift_start, shift_end, work_session_start/stop); carries odometer reading
- `JobEventStaff` — actual crew present at a given event; `man_hour_rate` snapshotted from `OrganisationMember.labor_hourly_rate` at log time
- `JobMaterial` — materials on a job: `quantity`, `cost` (actual paid), `price` (final billable)
- `JobEventMaterial` — links a material to a specific event within a job

### `Inventory`

Materials stock and supplier management.

- `Material` — canonical definition: name, unit, category
- `Lot` — physical stock unit: material, storage location, quantity, received_at
- `Movement` — audit trail of all quantity changes (`:receive | :consume | :adjust`)
- `Supplier` — name, contact info
- `SupplierCatalog` — a supplier's catalogue of items
- `SupplierCatalogItem` — material, `unit_price` (list price; often absent for plants)
- `PurchaseOrder` — supplier, status, ordered_at
- `PurchaseOrderItem` — catalog item, quantity, unit_price
- `Receiving` — records a PO receipt, creating Lot records at the destination StorageLocation

### `Operations`

Physical locations.

- `Venue` — named location (nursery, warehouse, job site)
- `StorageLocation` — a specific storage area within a venue (e.g. "Greenhouse A", "Yard B")

---

## Cross-Domain Rules

- `Job.engagement_id` links jobs to the engagement they execute. Jobs also link to `Invoice` via `invoice_id` for billing.
- `JobStaff.member.labor_hourly_rate` is the **live** rate — used only for pre-job estimation.
- `JobEventStaff.man_hour_rate` is **snapshotted** at log time — used for realized cost. Once written, it never changes.
- `EngagementMaterial` (quote) and `JobMaterial` (execution) are independent records. Prices legitimately diverge between quoting and execution.
- `SupplierCatalogItem.unit_price` is the catalogue list price — often absent for plants. `JobMaterial.cost` is what the org actually paid on the supplier invoice.

---

## Multitenancy Fragment

All org-scoped resources use:

```elixir
defmodule OpenSauce.Concerns.Multitenanted do
  use Spark.Dsl.Fragment, of: Ash.Resource

  multitenancy do
    strategy :attribute
    attribute :organisation_id
  end

  attributes do
    attribute :organisation_id, :uuid, allow_nil?: false, public?: false
  end

  relationships do
    belongs_to :organisation, OpenSauce.Accounts.Organisation,
      domain: OpenSauce.Accounts,
      allow_nil?: false
  end
end
```

---

## Session & Auth Flow

1. **AshAuthentication** — authenticates `User` via magic link; no tenant set yet
2. **Org picker** — query `OrganisationMember` (unscoped) by `user_id` for that user's orgs
   - Single org → skip picker, go straight to app
   - Multiple orgs → show picker
3. **Session** — store `user_id` + `organisation_id`; one active org at a time
4. **`on_mount`** — load `OrganisationMember` by `user_id` + `organisation_id`; assign as `current_member`; suspended members are redirected to sign-in
5. **Every Ash action** — `actor: current_member, tenant: current_member.organisation_id`
6. **Org switch** — verify membership, load new `OrganisationMember`, replace in session

The actor is always `OrganisationMember`, not `User`. Policies check `actor.role`.

---

## Router Structure

Staff routes live under `/manage/`, split into two live session groups:

- `:admin_routes` — manager and owner only
- `:manage_routes` — all staff

The client-facing portal lives under `/portal/` and is auth'd by a separate token mechanism.

---

## File Layout

```
lib/opensauce/
  concerns/
    multitenanted.ex        # Ash fragment — org scope
    venued.ex
  accounts/
    accounts.ex             # Ash.Domain
    organisation.ex
    user.ex
    organisation_member.ex
    tax_rate.ex
    api_key.ex
  crm/
    crm.ex                  # Ash.Domain
    customer.ex
    address.ex
    engagement.ex
    engagement_material.ex
    engagement_image.ex
    invoice.ex
  work/
    work.ex                 # Ash.Domain
    job.ex
    job_staff.ex
    job_event.ex
    job_event_staff.ex
    job_material.ex
    job_event_material.ex
    job/calculations/       # Ash.Resource.Calculation modules
  inventory/
    inventory.ex            # Ash.Domain
    material.ex
    lot.ex
    movement.ex
    supplier.ex
    supplier_catalog.ex
    supplier_catalog_item.ex
    purchase_order.ex
    purchase_order_item.ex
    receiving.ex
  operations/
    operations.ex           # Ash.Domain
    venue.ex
    storage_location.ex
```

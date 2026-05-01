---
layout: ../../layouts/DocsLayout.astro
title: Domain Architecture
---

# OpenSauce — Domain Architecture

## Tenancy Model

Row-level multitenancy via `AshPostgres` (`:attribute` strategy).  
All scoped resources carry `organisation_id`. The tenant boundary is always the **Organisation**.  
`venue_id` is a regular required attribute on venue-scoped resources — not a second tenancy layer.

### Unscoped (public schema)

| Resource | Domain | Notes |
|---|---|---|
| `Organisation` | `Accounts` | The billing/tenant account |
| `User` | `Accounts` | Identity only |
| `OrganisationMember` | `Accounts` | Join: user ↔ org, carries `role` |

`OrganisationMember.role` — `:owner | :manager | :staff | :readonly`

---

## Domains & Resources

### `Accounts`

Unscoped bootstrap layer. Resolves tenant before any domain call.

- `Organisation` — name, slug, subscription status
- `User` — email, auth state
- `OrganisationMember` — role, user_id, organisation_id

### `Operations`

The physical layer. Everything with a location.

**Org-scoped**
- `Venue` — name, address, timezone, type (`:kitchen | :warehouse | :other`)

**Venue-scoped** (org-scoped + venue_id required)
- `StorageLocation` — name, e.g. "Freezer 5", "Walk-in A"; belongs to a Venue
- `Shift` — date, staff member, venue

> A warehouse is a Venue with `type: :warehouse`. Storage locations hang off it uniformly.

### `Inventory`

**Org-scoped**
- `Ingredient` — canonical definition: name, base unit, allergens, category
- `Supplier` — name, contact info, payment terms

**Venue-scoped**
- `IngredientLot` — physical stock: ingredient, storage_location, quantity, unit, received_at, expiry
- `StockMovement` — audit trail of all quantity changes (receive, consume, waste, transfer)
- `SupplierPackaging` — supplier's unit (e.g. "25 kg sack"), price, maps to Ingredient

### `Catalog`

**Org-scoped**
- `Recipe` — name, yield quantity, yield unit
- `RecipeIngredient` — ingredient, quantity, unit; belongs to Recipe

**Venue-scoped**
- `Menu` — name, active period
- `MenuItem` — recipe, price, display name; belongs to Menu

### `Purchasing`

**Org-scoped**
- `PurchaseOrder` — supplier, status, ordered_at
- `PurchaseOrderLine` — supplier_packaging, quantity, unit_price

> Receiving a PO creates `IngredientLot` records at the destination `StorageLocation`.

---

## Cross-Domain Rules

- `Recipe` and `Ingredient` are org-scoped — shared across all venues in the group.
- Stock (`IngredientLot`) is venue-scoped — each kitchen/warehouse tracks its own.
- A `StockMovement` of type `:transfer` links two `IngredientLot` records (source venue → dest venue).
- `Shift` is venue-scoped; `OrganisationMember` is org-scoped. A staff member can have shifts at multiple venues.

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

Venue-scoped resources additionally declare:

```elixir
attributes do
  attribute :venue_id, :uuid, allow_nil?: false, public?: false
end

relationships do
  belongs_to :venue, OpenSauce.Operations.Venue,
    domain: OpenSauce.Operations,
    allow_nil?: false
end
```

---

## Session & Auth Flow

1. **AshAuthentication** — authenticates `User` (email/password or magic link); no tenant set yet
2. **Org picker** — query `OrganisationMember` (unscoped) by `user_id` for that user's orgs
   - Single org → skip picker, go straight to dashboard
   - Multiple orgs → show picker
3. **Session** — store `user_id` + `organisation_id`; one active org at a time
4. **`on_mount`** — load `OrganisationMember` by `user_id` + `organisation_id`; assign as `current_member`
5. **Every Ash action** — `actor: current_member, tenant: current_member.organisation_id`
6. **Org switch** — verify membership, load new `OrganisationMember`, replace in session

```elixir
# Helper used at every callsite
defp opts(socket), do: [actor: socket.assigns.current_member, tenant: socket.assigns.current_member.organisation_id]

# Every domain call looks like this
OpenSauce.Inventory.list_ingredients!(opts(socket))
```

`current_user` (the `User` struct) remains on the socket for AshAuthentication internals (sign-out, password reset). It is never passed as `actor` to domain calls.

---

## File Layout

```
lib/opensauce/
  concerns/
    multitenanted.ex       # Spark.Dsl.Fragment — org scope
    venued.ex
  accounts/
    accounts.ex            # Ash.Domain
    organisation.ex
    user.ex
    organisation_member.ex
  operations/
    operations.ex
    venue.ex
    storage_location.ex
    shift.ex
  inventory/
    inventory.ex
    ingredient.ex
    ingredient_lot.ex
    stock_movement.ex
    supplier.ex
    supplier_packaging.ex
  catalog/
    catalog.ex
    recipe.ex
    recipe_ingredient.ex
    menu.ex
    menu_item.ex
  purchasing/
    purchasing.ex
    purchase_order.ex
    purchase_order_line.ex
```

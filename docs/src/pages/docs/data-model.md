---
layout: ../../layouts/DocsLayout.astro
title: Data Model & Calculations
---

# Data Model & Calculations

This page walks the full entity tree and traces how every cost and total is computed, from organisation config through to invoicing.

---

## Organisation (config layer)

```
Organisation
  ├── currency                     (CAD default)
  ├── tax_mode                     :inclusive | :exclusive
  ├── labor_overhead_percent       multiplier applied on top of all labor costs
  ├── mileage_cost_per_km          applied to realized odometer deltas
  ├── next_invoice_number          auto-incremented on Invoice.create
  ├── estimate_sign_off_items      [{label, body}] client acknowledges before signing
  └── TaxRate[]
        name, rate%, is_compound, registration_number, position
        ordering matters: compound rates stack on the running subtotal, not the original
```

---

## Staff (rate source)

```
OrganisationMember
  └── labor_hourly_rate            live value; snapshotted at event log time
```

---

## Pre-work: Engagement (quote)

```
Engagement
  ├── install_price                one-off fee to client
  ├── maintenance_price_annual     recurring annual fee
  ├── status                       draft → proposed → signed → in_progress → completed | cancelled
  ├── signature                    set by :sign action; locks scope fields after signing
  │
  ├── [calc] total_quoted_value    = install_price + maintenance_price_annual
  │
  ├── EngagementMaterial[]         planned materials at quote time
  │     ├── quantity
  │     ├── cost                   estimated supplier price — used to verify margin before signing
  │     └── price                  planned billable rate to client
  │         NOT carried to execution; JobMaterial tracks the execution values independently
  │
  └── EngagementImage[]
        type: :painting            controls invoice description copy:
                                   :painting present → "Garden as drawn, installed|maintained"
                                   no painting      → "Garden as described, installed|maintained"
```

---

## Execution: Job → Events → Realized Cost

```
Job
  ├── type                         :client_work | :shift | :internal_work
  ├── duration_estimate            minutes (tentative, set when scheduling)
  ├── realized_cost                nil until :complete; written once by SnapshotRealizedCost
  │
  ├── JobStaff[]                   tentative crew assignments
  │     └── member.labor_hourly_rate   live rate — for estimation only
  │
  ├── [calc] man_hour_rate         = Σ(JobStaff[].member.labor_hourly_rate)
  ├── [calc] estimated_man_hours   = duration_estimate / 60
  ├── [calc] estimated_cost        = (estimated_man_hours × man_hour_rate × (1 + overhead))
  │                                  + materials_cost
  │
  ├── JobMaterial[]                materials on this specific job
  │     ├── quantity
  │     ├── cost                   what the org actually paid on the supplier invoice (nil until known)
  │     └── price                  final billable rate to client (nil until invoicing)
  │         qty=0 is valid (gifted/presented plant); use destroy to remove, not qty=0
  │
  ├── [calc] materials_cost        = Σ(quantity × supplier_catalog_item.unit_price)
  │                                  uses catalogue list price, NOT JobMaterial.cost
  │
  ├── JobEvent[]                   append-only field log; no update action
  │     ├── data (union type)
  │     │     :arrival / :departure          paired for non-shift labor timing
  │     │     :shift_start / :shift_end      paired for :shift labor timing
  │     │     :work_session_start / :stop    tag only (no odometer)
  │     ├── timestamp                        user-recorded; not the DB insert time
  │     ├── odometer_reading                 on arrival / departure / shift events
  │     │
  │     └── JobEventStaff[]        actual crew present for THIS event
  │           └── man_hour_rate    snapshotted from OrganisationMember at log time
  │                                ← KEY INVARIANT: never recalculated after logging
  │
  ├── [calc] duration              = Σ elapsed minutes across arrival→departure pairs
  ├── [calc] mileage_km            = odometer_end − odometer_start per pair
  │
  └── On :complete → SnapshotRealizedCost
        1. Load all JobEvents with event_staff
        2. Pair-walk events: arrival/departure (non-shift) or shift_start/shift_end (:shift)
        3. For each pair:
             hours     = (close.timestamp − open.timestamp) in seconds ÷ 3600
             rate      = Σ(open.event_staff[].man_hour_rate)   ← snapshotted rate
             pair_cost = hours × rate × (1 + labor_overhead_percent)
        4. mileage   = mileage_km × mileage_cost_per_km
        5. materials = materials_cost (catalogue price × qty)
        6. realized_cost = Σ(pair_costs) + mileage + materials
```

---

## Billing: Invoice

```
Invoice
  ├── amount                       subtotal (pre-tax); set by the user when creating the invoice
  ├── status                       :draft → :sent → :paid | :void
  │
  ├── line_items                   [{type, label, amount, group_id?, date?}]
  │     type: "engagement"         the engagement fee row (bold, top of group)
  │     type: "job"                a job row indented under its engagement
  │     type: "custom"             freeform line; can be ungrouped or inside a group
  │     group_id                   groups engagement + its job rows together visually
  │
  ├── snapshot                     frozen at :sent or :paid time; nil until then
  │     "org"                      name, legal_name, currency, tax_mode, payment_info, logo_key…
  │     "customer"                 name, email, billing_address (street/city/province/zip)
  │     "tax_lines"                [{name, rate, registration_number, amount}]
  │     "grand_total"              string decimal
  │     Once set, the view loads all totals from snapshot instead of recomputing.
  │
  └── Tax computation (live until snapshot is frozen)
        Exclusive mode:
          For each TaxRate in position order:
            base   = running total (is_compound) OR original subtotal (not compound)
            amount = base × (rate / 100), rounded to 2dp
          grand_total = amount + Σ(tax amounts)
        Inclusive mode:
          grand_total = amount (taxes embedded; no breakdown shown)
```

---

## Key Invariants

| Rule | Detail |
|---|---|
| Rate snapshotting | `JobEventStaff.man_hour_rate` is frozen at log time; changes to `OrganisationMember.labor_hourly_rate` after that do not affect past events |
| `materials_cost` calc source | Uses `SupplierCatalogItem.unit_price` (catalogue price), not `JobMaterial.cost` (actual paid) |
| EngagementMaterial vs JobMaterial | Parallel but independent — quote price ≠ execution price by design; the divergence is intentional data |
| `realized_cost` write-once | Written on `:complete`; not recomputed afterward |
| Invoice snapshot | Written on `:sent` and `:paid`; after that, the view ignores live tax rates and org field changes |
| Compound tax stacking | Each compound tax applies to the running total (subtotal + all previous tax amounts), not the original subtotal |
| Zero-qty materials | `JobMaterial.quantity = 0` records a gifted/presented plant; it is not a removal signal. Use `destroy` to remove the line |
| Engagement lock after signing | The `:sign` action sets status to `:signed` and embeds the signature. After that, `scope_title`, `scope_description`, `garden_id`, prices, and term dates cannot be changed |

---

## Stub Calculations (not yet implemented)

These calculations are defined on `Engagement` but return `nil` until Invoice data is wired in:

- `total_invoiced` — sum of paid invoices linked to the engagement
- `total_realized_cost` — sum of `Job.realized_cost` for all jobs under the engagement
- `realized_margin` — `total_invoiced − total_realized_cost`
- `realized_margin_percent` — `realized_margin / total_invoiced × 100`

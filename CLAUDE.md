# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
mix setup              # Full setup: deps, ash.setup, assets, seeds
mix phx.server         # Start dev server at localhost:4000
mix test               # Run all tests (runs ash.setup --quiet first)
mix test path/to/test.exs            # Run a single test file
mix test path/to/test.exs:42         # Run a specific test at line
mix format             # Format all code (Styler, Spark, Tailwind, HEEx)
mix dialyzer           # Static type analysis
mix ash.setup          # Run migrations + Ash introspection
mix ash.codegen <name> # Generate snapshots + migrations after resource changes
mix ash.reset          # Drop, create, migrate, seed
docker-compose up -d   # Start PostgreSQL 16 + MinIO (S3-compatible storage)
```

## Architecture

OpenSauce Dirt is an ERP for small landscaping and gardening businesses, built on **Ash Framework + Phoenix LiveView + PostgreSQL**. Core workflows are client engagement management, field job scheduling, crew costing, and materials/inventory.

### Domain Structure (Ash Domains)

Each domain is an `Ash.Domain` containing related `Ash.Resource` modules:

- **OpenSauce.Accounts** — Users, Organisations, OrganisationMembers (with `labor_hourly_rate`), ApiKeys, TaxRates; org-level config includes `labor_overhead_percent` and `mileage_cost_per_km`
- **OpenSauce.CRM** — Customers, Addresses (garden sites), Engagements (contract lifecycle with signature capture), EngagementImages (photos and paintings — paintings determine invoice description style), EngagementMaterials, Invoices
- **OpenSauce.Orders** — Jobs (`:client_work`, `:shift`, `:internal_work`), JobEvents (arrival/departure log with `event_staff` attendance + rate snapshots), JobStaff (tentative crew for calendar + estimation), JobMaterials, JobEventMaterials
- **OpenSauce.Inventory** — Materials, Lots, Movements (consume/receive/adjust), PurchaseOrders, PurchaseOrderItems, Suppliers, SupplierCatalogs, Receivings
- **OpenSauce.Operations** — Venues, StorageLocations (nursery/warehouse locations)

### Resource Pattern

All domain entities use `AshPostgres.DataLayer` with `Ash.Policy.Authorizer` and the `OpenSauce.Concerns.Multitenanted` fragment (attribute-based multitenancy on `organisation_id`). Business logic lives in Ash actions with custom changes (`changes/` subdirs) and validations. Domain modules expose a code interface via `:define`.

After any resource change, run `mix ash.codegen <migration_name>` to update both migrations and `priv/resource_snapshots/`; commit both together.

### File Storage

`OpenSauce.Storage` is a behaviour with `put/4`, `url/1`, and `delete/1` callbacks. Set the active adapter via `config :opensauce, storage_adapter: MyAdapter`. `OpenSauce.Storage.Local` is the default — files go to the configured `upload_dir`, served at `/uploads/`. Swap to S3 by implementing the behaviour and updating config.

### Web Layer

- **Router**: `lib/opensauce_web/router.ex` — staff routes under `/manage/`, split into manager-only and staff-accessible session groups
- **LiveViews**: `lib/opensauce_web/live/manage/` — jobs, customers, engagements, inventory, purchasing, invoices, settings
- **Components**: `lib/opensauce_web/components/` — core, forms, data_vis, page, layouts
- **Navigation**: `lib/opensauce_web/navigation.ex` — section definitions with sub-links; `live_nav.ex` maps URL prefixes to nav sections
- Auth via `on_mount` hooks using AshAuthenticationPhoenix

### Key Business Flows

- **Job scheduling**: Jobs are `:client_work`, `:shift` (container), or `:internal_work`. Shifts hold child jobs. Tentative crew is set via `JobStaff`. Jobs carry `duration_estimate` and calculate `estimated_cost` from tentative staff rates × overhead.
- **Job costing**: `JobEvent` logs arrival/departure with an `event_staff` list (actual crew present, rates snapshotted at log time). `realized_cost` is computed from all JobEvents and stored when the job is marked `:complete` — supports multi-visit jobs where a job is rescheduled but events accumulate.
- **Engagement → invoice**: Engagements track install/maintenance pricing, client signatures, and attached images. Paintings (`:painting` type EngagementImage) make the invoice read "Garden as drawn, installed|maintained"; without them it reads "Garden as described, installed|maintained".
- **Inventory**: Materials tracked in Lots via Movements (receive/consume/adjust). Purchase orders flow through supplier catalogues with lot venue awareness.

## Testing

- **Test support**: `test/support/data_case.ex` (database tests), `test/support/conn_case.ex` (LiveView tests), `test/support/factory.ex`
- **Factory** uses Ash actions directly to create test entities
- **Helper functions**: `staff_actor()` and `admin_actor()` create test users with appropriate roles
- **LiveView tests** use `Phoenix.LiveViewTest` with `live/2`, `element/2`, `render_click/1`, `form/3`, `render_submit/1`
- Tests use PostgreSQL sandbox in manual mode (async-compatible)

## Formatting & Style

- **Styler** enforces Elixir code style (AST-based linter + formatter)
- **Spark.Formatter** handles Ash DSL block ordering (section order defined in config)
- **TailwindFormatter** orders CSS classes
- **Phoenix.LiveView.HTMLFormatter** formats HEEx templates
- All four run via `mix format`

## Commit Convention

Commits follow the pattern: `type(scope): description` (e.g., `feat(jobs):`, `fix(crm):`, `chore(inventory):`)

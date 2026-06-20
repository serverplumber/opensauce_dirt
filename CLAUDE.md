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

- **Router**: `lib/opensauce_web/router.ex` — staff routes under `/manage/`, split into manager-only (`admin_routes`) and staff-accessible (`manage_routes`) session groups
- **LiveViews**: `lib/opensauce_web/live/manage/` — jobs, customers, engagements, inventory, purchasing, invoices, account, org; plus legacy `settings_live/` (desktop scaffolding, being migrated out)
- **Components**: `lib/opensauce_web/components/` — `core.ex` (shared UI primitives), `page.ex` (bottom nav shell + legacy desktop layout components), `layouts.ex` (`mobile_shell` is the active layout; `sidebar_layout` is defunct)
- **Navigation**: bottom nav bar defined in `page.ex`; `live_nav.ex` maps URL prefixes to active nav tab
- Auth via `on_mount` hooks in `live_user_auth.ex` — actor is `OrganisationMember`, not `User`; suspended members are redirected to sign-in

### Key Business Flows

- **Job scheduling**: Jobs are `:client_work`, `:shift` (container), or `:internal_work`. Shifts hold child jobs. Tentative crew is set via `JobStaff`. Jobs carry `duration_estimate` and calculate `estimated_cost` from tentative staff rates × overhead.
- **Job costing**: `JobEvent` logs arrival/departure with an `event_staff` list (actual crew present, rates snapshotted at log time). `realized_cost` is computed from all JobEvents and stored when the job is marked `:complete` — supports multi-visit jobs where a job is rescheduled but events accumulate.
- **Engagement → invoice**: Engagements track install/maintenance pricing, client signatures, and attached images. Paintings (`:painting` type EngagementImage) make the invoice read "Garden as drawn, installed|maintained"; without them it reads "Garden as described, installed|maintained".
- **Inventory**: Materials tracked in Lots via Movements (receive/consume/adjust). Purchase orders flow through supplier catalogues with lot venue awareness.
- **Job materials pricing**: `JobMaterial` carries two optional price fields separate from the catalogue price on `SupplierCatalogItem.unit_price`. `cost` is what the org actually paid externally for this specific job (supplier invoice price, which often differs from or is absent from the catalogue). `price` is the MSRP or billable rate to the client. Both are nil by default and filled in when known — many plants have no catalogue price at all. On the materials screen, tapping a card opens a bottom sheet to edit qty, cost, and price together. **Setting qty to 0 does not remove the item** — a zero-qty line is valid and intentional: it records a plant being presented or gifted to a client (track it with a note). The × button on the card is the only way to actually remove a material from the job.

## Testing

- **Test support**: `test/support/data_case.ex` (database tests), `test/support/conn_case.ex` (LiveView tests), `test/support/factory.ex`
- **Factory** uses Ash actions directly to create test entities
- **Helper functions**: `staff_actor()` and `admin_actor()` create test users with appropriate roles
- **LiveView tests** use `Phoenix.LiveViewTest` with `live/2`, `element/2`, `render_click/1`, `form/3`, `render_submit/1`
- Tests use PostgreSQL sandbox in manual mode (async-compatible)

## Product strategy: mobile only

**This is a mobile field app. There is no desktop product.**

The codebase contains a legacy desktop UI — `sidebar_layout` in `layouts.ex`, the light-theme `surface`/`section`/`two_column` components in `page.ex`, and the `settings_live/` LiveViews (org form, members, API keys, calendar feed, CSV import/export). That code was scaffolding used to get the data model stood up quickly. It is now defunct.

**Rules:**
- Never use `sidebar_layout`, `surface`, `section`, `two_column`, or `toggle_bar` for new work.
- Never use light-theme Tailwind classes (`bg-white`, `text-stone-*`, `border-gray-*`, etc.) on any screen a user will see.
- Every new screen and every migrated screen uses the dark soil palette, bottom nav shell (`mobile_shell`), and the patterns described below.
- When a feature request touches something that only exists in the desktop `settings_live/` screens, port the behaviour to a mobile screen as part of that task — do not leave it in the old desktop code.

**Desktop code as reference only:** The `settings_live/` components are useful for understanding what business logic already exists (Ash actions, form flow, validation). Read them for behaviour; never copy their markup or use their components.

**Future desktop:** A proper wide-screen UI may be built later, from scratch, for workflows that genuinely don't fit a phone (bulk data editing, reporting dashboards, etc.). That is a separate future project. Do not design current mobile screens to accommodate it.

## Mobile UI Theme

The entire app is a **dark-first mobile field app**. All screens use the dark soil palette, Bricolage Grotesque headings, and Hanken Grotesk body text.

### Palette

| Token | Hex | Use |
|---|---|---|
| `bg` | `#16140E` | Page / shell background |
| `paper` | `#211E16` | Cards, modals, nav bar |
| `leaf` | `#54B57E` | Primary accent — buttons, active states, borders |
| `leaf-bright` | `#6BCB93` | Hover / selected highlight, status chip text |
| `text` | `#F4EFE2` | Primary body text |
| `muted` | `#9A9384` | Secondary text, inactive nav labels |
| `dim` | `#6E675A` | Tertiary text, labels, disabled states |
| `border` | `rgba(52,48,37,0.58)` | Card borders, dividers, input borders |
| `rose` | `#E87E7E` | Validation errors |
| `amber` | `#DB9258` | Manager/owner role accents |
| `sky` | `#5AB4D8` | Completed status, design/consultation category |

### Typography

- **Headings** (`h1`, modal titles, screen titles): `font-family: 'Bricolage Grotesque', sans-serif`, bold, negative letter-spacing
- **Body / UI**: `font-family: 'Hanken Grotesk', system-ui, sans-serif`
- Both fonts are loaded in `root.html.heex` from Google Fonts
- Labels above form fields: `.dark-label` CSS class — 11.5px, 700 weight, 0.06em tracking, uppercase, `#6E675A`

### Interactive states

- **Hover**: Always gated with `@media (hover: hover)` so it never fires on touch. Bake this into CSS classes, never use Tailwind `hover:` utilities on touch-targeted elements.
- **Active / tap**: Add `ontouchstart=""` to buttons and links that need iOS `:active` to fire.
- **Focus**: Leaf green ring — `border-color: #54B57E; box-shadow: 0 0 0 3px rgba(84,181,126,0.18)`.

### CSS classes (app.css)

Form inputs: `.dark-label`, `.dark-select` (includes SVG chevron arrow), `.dark-input`, `.dark-textarea`, `.dark-field-error`

Job list: `.jcard` / `.jcard.live`, `.dayrow`, `.pill` (`.live`, `.sched`, `.done`, `.cancel`), `.dot` / `.dot.pulse`, `.jcat`, `.catdot`, `.crewrow`, `.av`, `.live-strip`, `.fab`

Buttons: `.seg-tab` / `.seg-tab--on`, `.leaf-btn`, `.btn-glow` / `.btn-glow--on`

Scrollbars: `.mobile-scroll`, `.dark-screen` — thin dark scrollbar, leaf green on hover.

### Icon conventions

**Edit action** — always use the pencil-on-square (not a naked pencil):
```html
<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
</svg>
```

### Glow button + validation pattern

The `<.glow_button>` component (`core.ex`) takes a `valid` boolean. When `false` (default): no animation, hover still shows a glow. When `true`: pulsing `glow-pulse` animation kicks in to call the user to action.

**The rule**: the button glows only when the form is ready to proceed. This is how the app guides users without blocking them.

**Canonical references** — always check these before implementing on a new screen:

- **`lib/opensauce_web/live/mobile_sign_in_live.ex`** — the login screen. `phx-change="update_email"` keeps `@email` in sync; `valid={valid_email?(@email)}` drives the glow. The email predicate is a simple `String.contains?(trimmed, "@")`. This is the template for single-field live validation.
- **`lib/opensauce_web/live/manage/job_live/new.ex`** — the new job screen (two steps). Step 1: `valid={step1_can_proceed?(@job_type, @service_category, @account_code)}` — glows once the key field is selected, full validation still runs on click. Step 2: `valid={true}` — always pulsing because step 1 already validated the required fields.
- **`lib/opensauce_web/live/manage/job_live/form_component.ex`** — the edit job modal. `valid={form_valid?(@form, @job_type)}` reads `form[:service_category].value` directly from the AshPhoenix form struct.

**Wiring pattern**:
1. `phx-change` on the form/input keeps a relevant assign up to date on every keystroke / selection
2. A small predicate function (`valid_email?/1`, `step1_can_proceed?/3`, `form_valid?/2`) inspects that assign — keep it simple, not a full validation rerun
3. Pass the result to `<.glow_button valid={...}>` — the button reacts in real time without a server round-trip for the animation

### Modals

The `<.modal>` component (`core.ex`) is globally dark-themed: `#211E16` background, `rgba(52,48,37,0.58)` ring, `rounded-2xl`. Title uses Bricolage Grotesque in `#F4EFE2`. Do not pass a light background override.

### Navigation

Bottom nav bar (`page.ex`) — `#211E16` bg, 74px tall. Active tab: `#54B57E`. Inactive: `#6E675A`. Nav highlights based on URL prefix via `live_nav.ex`.

**More sheet** slides up from the bottom and contains overflow nav links (Inventory, Engagements, Venues, Invoices, Settings) plus a user identity card at the bottom showing the user's avatar monogram, display name, and role pill — tapping it navigates to `/manage/account`.

**Account screen** (`/manage/account`) — user's name (editable), org info (read-only), switch org (if multiple memberships), sign out. Owners get a pencil icon to navigate to `/manage/org`.

**Org screen** (`/manage/org`, manager+) — edit org fields (name, currency, tax mode, overhead, mileage, email from), manage staff (add, edit role/rate/title, suspend/activate). Suspension sets `OrganisationMember.status = :suspended` and blocks login; the row is never deleted (historical data).

**Bottom sheets** (`z-[60]`) are used for forms that overlay the current screen (invite member, edit member, sign-out confirmation). They must use `z-[60]` to clear the bottom nav at `z-50`.

**Sticky CTAs** sit directly above the nav bar at `position:fixed; bottom:74px`. Background `#16140E` with a `rgba(52,48,37,0.58)` top border. Always use `<.glow_button>` here.

### Things that don't belong in job cards

Never show cost estimates or time estimates in job list cards — those belong on detail/event screens only.

## Formatting & Style

- **Styler** enforces Elixir code style (AST-based linter + formatter)
- **Spark.Formatter** handles Ash DSL block ordering (section order defined in config)
- **TailwindFormatter** orders CSS classes
- **Phoenix.LiveView.HTMLFormatter** formats HEEx templates
- All four run via `mix format`

## Form Input Formatting

Client-side input hooks live in `assets/js/hooks/formatters.js` and are registered in `assets/js/hooks/index.js`. Attach them with `phx-hook="HookName"` on any `dark-input`.

| Hook | Field types | Behaviour |
|---|---|---|
| `FormatPhone` | `type="tel"` phone fields | Strips non-digits, formats to `(xxx) xxx-xxxx` on every `input` event; truncates at 10 digits. |
| `FormatPostal` | `type="text"` postal code | Strips spaces, uppercases, inserts space after position 3 → `A1A 1A1`; max 7 chars. Canadian only. |
| `TitleCase` | `type="text"` city, country | Capitalises first letter of each word on `blur`. Fires once when the user leaves the field. |

**HTML `type` attributes** drive the mobile keyboard:
- `type="tel"` — numeric dial pad (phone fields)
- `type="email"` — email keyboard with `@` key
- `type="url"` — URL keyboard with `.com` shortcut
- `type="number"` — numeric keyboard (rates, amounts)

**Server-side nil handling** — address and contact fields are all `allow_nil? true` on the resource. The `nilify_map_values/1` helper (`org_live.ex`) converts empty strings to `nil` before passing address params to CRM functions. Apply the same pattern whenever you collect address or optional text params from a form.

```elixir
defp nilify(""), do: nil
defp nilify(s), do: s
defp nilify_map_values(map), do: Map.new(map, fn {k, v} -> {k, nilify(v)} end)
```

## Commit Convention

Commits follow the pattern: `type(scope): description` (e.g., `feat(jobs):`, `fix(crm):`, `chore(inventory):`)

## Known Gotchas

**AshPhoenix.Form.submit drops all but the first element of an `{:array, :map}` argument** unless that argument is configured as a nested form via the `forms:` option. When an action takes an `{:array, :map}` argument assembled in assigns (not from form inputs), bypass `AshPhoenix.Form.submit` and call Ash directly:

```elixir
Resource
|> Ash.Changeset.for_create(:action, params, actor: member, tenant: member.organisation_id)
|> Ash.create()
```

The `AshPhoenix.Form` struct can still be used for field-level error display on failure via `AshPhoenix.Form.validate(form, scalar_params, errors: true)`.

# Handoff: Mobile field-app shell — Login, Customers & Ad-hoc jobs

## Overview
This package covers the **mobile-first reframe** of OpenSauce Dirt for field crews: a
bottom-tab phone shell plus four new/updated flows that were wireframed in this round:

1. **Bottom navigation** — `Today · Jobs · Customers · POs · More` (replaces the old tab set)
2. **L · Login & onboarding** — passwordless magic link → org selection (or create org)
3. **H · Customer creation** — contact + gardens, with one garden flagged as the billing address
4. **I · Customers** — list + customer summary, with a one-tap "new engagement" launch
5. **K · Job creation** — the foundational planned-job flow (type → context → schedule, crew & estimate)
6. **J · Ad-hoc job** — unplanned visit logging (arrival OR departure), gated to "no active job"; the special case of K

The good news: **almost every screen maps onto domain code that already exists** in the
Elixir/Ash backend. The work is mostly (a) a new mobile presentation layer and (b) a small
number of new business rules. Each section below states precisely what exists vs. what's new.

## About the design files
This bundle contains **two kinds of file**:
- **`Login Polished.html` (+ `Login Polished (light).html`)** — a **high-fidelity** mockup of the L flow in the final dark theme. Visual source of truth for Section L and the token reference for everything else.
- **`Jobs Polished.html`** — a **high-fidelity** mockup of the **Jobs tab** (the list behind bottom-nav → Jobs) in the same dark theme, including the polished bottom nav. Visual source of truth for the Jobs list + the bottom-nav bar.
- **`Mobile-First Wireframes.html` + the `*.jsx` files** — **low-fidelity** wireframes (hand-drawn "marker on soil" style) showing structure, flow, and intent for all sections, with rationale annotations.

## Fidelity: MIXED — read carefully
- **HIGH fidelity — match the mockups pixel-close:**
  - **Section L (Login & onboarding)** → `Login Polished.html` (3 screens: L1 sign in, L2 check email, L3 choose org).
  - **Jobs list + bottom nav** → `Jobs Polished.html` (1 screen). Together these are the **4 polished screens** in this bundle. Match their colors, type, spacing, radii, and 56px touch targets; the matching hand-drawn wireframes are superseded for styling (still useful for flow logic / annotations).
- **Everything else (H, I, K, J, the other tabs) is LOW fidelity.** Treat those wireframes as a layout & functionality guide only; apply the **dark theme tokens below** (the same system the 4 polished screens use). Do not invent a new palette.

> The polished design uses a **dark, low-glare scheme** — deliberately, because the users are gardeners/field crews whose eyes are calibrated to daylight and growlights and who dislike bright UI. This is the product direction; it supersedes the lighter stone/amber sketch in `org_pick_live.ex`. Build dark-first.

In all cases: **do not port the HTML.** Recreate the screens in Phoenix LiveView + HEEx + TailwindCSS using the components in `lib/opensauce_web/components/`, and drive behavior through the existing Ash actions described below.

---

## Target architecture (read first)
- **Stack:** Elixir 1.18+, Ash Framework (domain modeling), AshPostgres, Phoenix LiveView + HEEx + TailwindCSS.
- **Domains:** `OpenSauce.Accounts`, `OpenSauce.CRM`, `OpenSauce.Orders`, `OpenSauce.Inventory`, `OpenSauce.Operations`.
- **Multitenancy:** every resource uses the `OpenSauce.Concerns.Multitenanted` fragment (attribute-based on `organisation_id`). Set the tenant from the actor; never query across orgs.
- **Web layer:** LiveViews live under `lib/opensauce_web/live/manage/` on `/manage/*` routes. The router has two live sessions: `:admin_routes` (manager+) and `:manage_routes` (staff+). Add field-crew screens to the staff-accessible group.
- **Forms:** always `to_form/2` in the LiveView + `<.form for={@form} id="...">` + `<.input field={@form[:field]} />`. Never touch a changeset in HEEx. Give every form/button a stable DOM id (for tests).
- **Collections:** use LiveView `stream/3` with `phx-update="stream"`; track counts/empty-state separately.
- **No `<script>` in HEEx:** JS hooks go in `assets/js` and wire through `app.js`.
- **After any resource change:** run `mix ash.codegen <name>` and commit the migration + `priv/resource_snapshots/` together.

### The mobile shell is NEW
Today the app is desktop-oriented: `/manage/*` routes with a **sidebar** and sub-links
defined in `lib/opensauce_web/navigation.ex`. The wireframes introduce a **bottom tab bar**
for phones. This presentation shell does not exist yet and must be built. It should reuse the
existing LiveViews/Ash actions behind each tab — it is a layout change, not a new app.

---

## Section 0 — Bottom navigation
**Wireframe:** the nav strip at the bottom of every primary screen. **Polished:** see the bottom bar in `Jobs Polished.html` — match that treatment (dark blurred bar, 5 tabs, active tab in growlight-green).
**Tabs, in order:** `Today` · `Jobs` · `Customers` · `POs` · `More`

| Tab | Routes to | Backing code | Status |
|-----|-----------|--------------|--------|
| **Today** | A field "today" dashboard (live job, up-next, inbox) | aggregates `Orders.Job` + `Orders.JobEvent` for the actor's day | **New screen**, existing data |
| **Jobs** | `/manage/jobs` | `job_live/index.ex` | Exists (desktop); **HIGH-fi mobile mockup → `Jobs Polished.html`** |
| **Customers** | `/manage/customers` | `customer_live/index.ex` | Exists; needs mobile layout |
| **POs** | `/manage/purchasing` | `purchasing_live/` | Exists; needs mobile layout |
| **More** | overflow menu → Inventory, Engagements, Venues, Invoices, Settings | existing `navigation.ex` sections | **New menu**, existing destinations |

**Implementation notes**
- Build a bottom-nav function component (e.g. in `components/page.ex`) that takes the active section and renders 5 tab targets via `<.link navigate={...}>`. Hit targets ≥ 44px.
- Reuse the active-section helpers already in `navigation.ex` (`jobs_active?/1`, `customers_list_active?/1`, etc.) to drive the highlighted tab.
- The "More" tab is an overflow sheet/menu listing the remaining `navigation.ex` sections, since five tabs can't hold all of them.
- The old tab labels (`Pickups`, `Stock`, `Schedule`, `Inventory`) are **removed** from the bar. Their destinations live under "More" or "POs".

### Jobs tab — the list screen (HIGH fidelity → `Jobs Polished.html`)
The Jobs tab itself has a polished mockup. Rebuild `job_live/index.ex` for mobile to match it.
- **Header:** just the "Jobs" title + a **Today / Upcoming / Done** segmented control with counts. (Search & filter buttons were intentionally dropped for v1 — don't add them back.)
- **Sections:** day-grouped (`Today` with the date, then `Tomorrow`, etc.). Use the existing read actions — `:list` (sorted by `scheduled_for`) and `:upcoming` — and group client-side, or add a read action per segment. Stream the rows (`phx-update="stream"`).
- **Card anatomy:** customer + garden (with a pin glyph), a **status pill** mapped from `Job.status` (`:in_progress` → green "On site" with a pulsing dot; `:scheduled` → muted time; `:completed` → "Done"; `:cancelled` → amber), the **service-category** swatch, scheduled time vs. `duration_estimate`, tentative **crew avatars** (from `JobStaff`), and the live **`estimated_cost`**. The in-progress card is emphasised (green border) and shows a running timer derived from the arrival `JobEvent.timestamp`.
- **FAB:** a green "+" floating above the nav → opens job creation (Section K).
- Preload `garden`, `staff_assignments`, and the `estimated_cost`/`duration` calcs before streaming so cards don't N+1.

---

## Section L — Login & onboarding (magic link → org selection)

### What already exists
- **Magic link auth** via `ash_authentication`. The sender is `OpenSauce.Accounts.User.Senders.SendMagicLink` (`lib/opensauce/accounts/user/senders/send_magic_link.ex`) — it emails a link to `/auth/user/magic_link?token=…`. Auth uses `AshAuthenticationPhoenix` with `on_mount` hooks.
- **Org selection** already has a LiveView: `OpenSauceWeb.OrgPickLive` (`lib/opensauce_web/live/org_pick_live.ex`). It loads `Accounts.list_memberships_for_user!/1`, **auto-redirects when the user has exactly one membership**, and otherwise renders a chooser. Picking navigates to `~p"/org/pick/#{organisation_id}"`.
- **Org creation** has a LiveView too: `OpenSauceWeb.OrgNewLive` (`org_new_live.ex`).

### Screens to build (HIGH fidelity — match `Login Polished.html`)
> `Login Polished.html` is the visual target for these three. Match it pixel-close; use the L1–L3 wireframes only for flow logic and the annotation rationale.

- **L1 · Sign in** — evergreen brand hero (sprout mark + "OpenSauce" wordmark + "Jobs, crews & gardens" tagline) over a single email field + one primary "Email me a magic link" action. Passwordless; no password field exists in the model, so don't add one. Submitting triggers the magic-link sender.
- **L2 · Check your email** — holding screen after submit. Shows the entered email, a resend action (add a client-side cooldown), and "use another email". This is a UI state on the sign-in LiveView; the actual sign-in completes when the user taps the emailed link (`/auth/user/magic_link?token=…`).
- **L3 · Choose organisation** — the mobile version of `OrgPickLive`. List each membership with org name + role (data is already `m.organisation.name` and `m.role`). Pre-highlight the most-recent org. **Keep the existing single-membership auto-redirect.**
  - **"Create org" replaces "join with invite code."** The dashed CTA routes to `OrgNewLive`. **Per the latest direction:** when the user has **zero** memberships, the create-org path is the default — skip the chooser and send them straight to org creation. (Today `OrgPickLive` renders an empty list in that case; add a zero-membership branch that `push_navigate`s to the new-org flow.)

### Gaps / decisions
- No invite-code flow is in scope. Don't build one.
- "Most-recent org" needs an ordering signal (e.g. last-used timestamp on `OrganisationMember`). If none exists, fall back to most-recently-created membership and note the follow-up.

---

## Section H — Customer creation (gardens + billing address)

> **This is the most important data rule in the set: every customer needs ≥1 garden, and exactly one garden is flagged as the billing address. Billing is NOT a separate address — it's a flag on a garden.**

### What already exists (strong match)
- **`OpenSauce.CRM.Customer`** (`lib/opensauce/crm/customer.ex`) — the `:create` action **already** accepts:
  - `billing_address` (map) and `garden_addresses` (array of maps), both wired through `manage_relationship`.
  - A **validation requiring at least one garden address** (`garden_addresses == [] → error`).
  - Company customers require `company_name_nickname`; `type` is `:individual | :company`.
- **`OpenSauce.CRM.Address`** (`lib/opensauce/crm/address.ex`) — has boolean flags `is_billing`, `is_garden`, `is_indoor`, plus `name`, `street`, `city`, `province`, `zip`, `country`, and `full_address`/`short_address` calculations.
- **`Customer` relationships** expose `has_one :billing_address` (filtered `is_billing == true`) and `has_many :garden_addresses` (filtered `is_garden == true`).
- **Form UI** already exists: `customer_live/form_component.ex` (desktop).

### Screens to build (mobile redesigns of the form)
- **H1 · New customer** — contact fields (name/company, phone, email) + a gardens list. First garden is auto-flagged `is_billing = true`. Block submit when gardens is empty (the Ash validation already enforces this server-side — mirror it in the UI).
- **H2 · Add garden** — `name` + address fields + access notes, and a **"use as billing address" toggle**. Turning it on must move the single `is_billing` flag off whatever garden held it.
- **H3 · Gardens & billing** — a **single-select** list (radio semantics) over the customer's gardens; choosing one sets `is_billing` on it and clears the others.

### Gaps / decisions — IMPORTANT
- **The "exactly one billing garden" invariant is NOT yet enforced in the domain.** `is_billing` is a plain boolean on each `Address`; nothing prevents zero or multiple billing addresses. **Add this rule to the `Customer` create/update actions** (a change/validation that ensures exactly one of the managed addresses has `is_billing == true`, defaulting to the first garden when unset). Run `mix ash.codegen` if you add attributes; pure validations/changes don't need a migration.
- **Access notes** field shown in H2 has no column on `Address` yet. Either add an attribute (e.g. `access_notes :string`) — which needs `mix ash.codegen` — or drop it from v1. Confirm with product.
- The wireframe treats "garden" and "billing" as the same address with two flags — which matches the schema exactly (`is_garden` + `is_billing` can both be true on one `Address`). Keep that model; don't create duplicate address rows.

---

## Section I — Customers (list + summary)

### What already exists
- **List:** `customer_live/index.ex`, backed by `Customer` read action `:list` (sorted by `first_name`, offset+keyset pagination, countable). Mobile list should use a LiveView `stream`.
- **Summary:** `customer_live/show.ex`. Customer already exposes `addresses`, `billing_address`, `garden_addresses`, `engagements`, `invoices`, and a `full_name` calculation.
- **Breadcrumb/section helpers** for customers + engagements are in `navigation.ex`.

### Screens to build
- **I1 · Customers list** — searchable (name, garden, postcode) with all/active/owing filters. Each row: name, garden count, and a right-rail badge (balance owing / active engagement count). Preload `garden_addresses`, `engagements`, and an invoices/balance aggregate with `Ash.Query.load/2` before streaming.
  - Search across gardens/postcodes means filtering on related `Address` fields — add a read action argument or filter rather than client-side filtering.
  - "Owing" / "active" badges need aggregates (balance due, count of in-progress engagements). Add Ash `aggregates`/`calculations` on `Customer` if not present (`mix ash.codegen` only if you add stored aggregates).
- **I2 · Customer summary** — the launch pad:
  - Identity (name, phone, email), KPI row (gardens count, active engagements, balance due).
  - Gardens list with the ★ **billing** flag surfaced (from `billing_address`).
  - Engagements list (live + past) from `customer.engagements`.
  - **Sticky "+ new engagement" CTA** — the primary action. It should ask **which garden** then open the engagement create flow (existing `engagement_live/`). Engagements are per-garden contracts, so garden selection is required.

### Gaps / decisions
- Balance-due and active-engagement counts may need new aggregates/calculations on `Customer`. Confirm what's already computed in `show.ex` before adding.

---

## Section K — Job creation (planned)

> The **foundational create flow**. Section J (ad-hoc) is its unplanned special case — build K
> first. A `Job` has a **type** (`:client_work | :shift | :internal_work`) that drives which
> fields appear. Two-step mobile flow: **(1) context** → **(2) schedule, crew & estimate**.

### What already exists (strong match)
- **`OpenSauce.Orders.Job`** (`lib/opensauce/orders/job.ex`) — the `:create` action already accepts `type`, `service_category`, `account_code`, `garden_id`, `engagement_id`, `containing_shift_id`, `actor_id`, `scheduled_for`, `duration_estimate`, `status`, `notes`. Defaults: `type :client_work`, `status :scheduled`.
- **Type-driven validations are already in the resource:**
  - `service_category` **required when** `type == :client_work` (one of `installation, delivery, pruning, consultation, design, opening, winterization, nursery_run, other`).
  - `account_code` **required when** `type == :internal_work` (`production | maintenance`).
  - `shift` jobs **cannot** have a garden or engagement.
  - `RequireGardenForAddressable` validation — addressable client-work categories need a `garden_id` (e.g. nursery_run/delivery don't).
- **Engagement → garden:** an `Engagement` belongs to a `garden` (Address) and a `customer`. Choosing an engagement should fill the customer + garden (the existing desktop `form_component.ex` filters gardens to the chosen engagement's garden — mirror that).
- **Crew assignment:** `OpenSauce.Orders.JobStaff` (`:assign` action, `accept [:job_id, :member_id, :organisation_id]`, unique per `[job_id, member_id]`) is the tentative-staff join. The single `actor_id` on the job is the lead/assignee; `staff_assignments` are the wider tentative crew that drive scheduling + cost.
- **Live cost estimate is already computed:** `Job` calculations `estimated_man_hours`, `man_hour_rate`, `materials_cost`, and `estimated_cost` (≈ man-hours × rate × overhead + materials). Load `estimated_cost` to show the running figure.
- **Existing form:** `job_live/form_component.ex` (desktop, `AshPhoenix.Form`) already implements type-switching, engagement→garden filtering, staff select, and the "cherry-pick materials from a prior job at this garden" affordance (`upstream_jobs` / `move_job_material`). Reuse its logic.

### Screens to build (mobile redesigns — LOW fidelity; use dark tokens)
- **K1 · Context** — `type` segmented control (Client work / Shift / Internal). For **client work**: an engagement picker (fills customer + garden), required **service-category** chips, and the **garden** (pre-filled from the engagement, editable; required for addressable categories). For **shift**: hide garden/engagement. For **internal work**: swap the category for the `account_code` select. Engagement is optional — if skipped, the user picks a garden directly.
- **K2 · Schedule & crew** — `scheduled_for` (date) + `duration_estimate` (minutes; shown as h/m), tentative **crew** add/remove (writes `JobStaff`), `notes` (max 2000), and a **live `estimated_cost`** panel that updates as crew changes. Sticky "Create job" commits the `:create` then assigns the crew.

### Gaps / decisions
- **Crew is a separate write.** The job `:create` takes a single `actor_id`; the wider tentative crew is `JobStaff` rows. Decide the order: create the job, then `JobStaff.assign` each member (wrap in a transaction or an Ash bulk action). The desktop form sets only `actor_id` today — multi-crew assignment from this screen is **new UI** over an existing action.
- **Duration units:** `duration_estimate` is stored in **minutes** (min 1). The wireframe shows "3h 30m" — convert in the UI.
- **"Cherry-pick materials from a prior job"** exists in the desktop form. Decide whether the mobile create surfaces it (it's genuinely useful for repeat gardens) or defers it to the job detail screen. Not drawn in the wireframe — confirm with product.
- **Status on create** defaults to `:scheduled`; `:in_progress` is triggered later by an arrival `JobEvent`. Don't set status from this screen.

---

## Section J — Ad-hoc job (unplanned visit)

> An ad-hoc job is an **unplanned visit created from the field**. It creates a `Job` plus an
> **arrival OR departure** `JobEvent`. It is **gated: only available when the crew has no
> active job** (one job at a time).

### What already exists
- **`OpenSauce.Orders.JobEvent`** (`lib/opensauce/orders/job_event.ex`):
  - A `data` **union** with tagged types including `:arrival` and `:departure` (both `OdometerData`), plus shift/work-session variants.
  - Events are **append-only** — created via the `:log` action (`accept [:job_id, :data, :timestamp, :note, :actor_id, :organisation_id]`); there is no update action by design.
  - `timestamp` is the **user-recorded** event time (not insert time) — exactly what the departure "time on site" span needs.
  - Relationships: `event_staff` (crew present, with rate snapshots) and `material_links` (`JobEventMaterial`) — this is how **materials/supplies used** attach to an event, same as a regular job.
- **`OpenSauce.Orders.Job`** supports types `:client_work`, `:shift`, `:internal_work`. An ad-hoc visit is a `:client_work` job.
- **Job UI** exists under `job_live/`: `index.ex`, `event_log_component.ex`, `event_materials_component.ex`, `materials_component.ex`. The materials-on-event UI already exists and should be reused.

### Screens to build
- **J1 · Entry + gate** — a "+ ad-hoc job" button on the Jobs screen. It is **disabled/locked while a job is active** (the active job is the gate). Enable it only when the actor has no in-progress job. Enforce this **server-side** too (a validation/precondition on the ad-hoc create), not just in the UI.
- **J2 · Arrival path** — garden picker + job description + an **arrival/departure switch** set to "Arriving now." On submit: create the `:client_work` Job and `:log` an **arrival** `JobEvent` with `timestamp = now`. This becomes the **active job**; the crew flags materials as they work and **closes it like a normal job** (existing close flow / departure event).
- **J3 · Departure path** — switch set to "Log a past visit." Everything in **one screen**:
  - Required **time-on-site span** (from → to). Persist as the event `timestamp` (use the departure time; capture the span in `OdometerData`/`note` as appropriate, or as two events if the model expects an arrival+departure pair — confirm against `OdometerData`).
  - **Materials used** + **supplies/consumables** via `JobEventMaterial` (reuse `event_materials_component.ex`).
  - Optional notes/photos (`note` field, max 500 chars).
  - On save the visit is committed retrospectively — **no active job is left open**.

### Gaps / decisions — IMPORTANT
- **The "no active job" gate is a NEW business rule.** Decide where "active job" lives (a job in an in-progress state for the actor / crew) and enforce it on the ad-hoc create action.
- **Departure-with-timespan semantics:** confirm whether a retrospective visit should write a single `:departure` event carrying the span, or a paired `:arrival` + `:departure`. Inspect `OpenSauce.Orders.JobEvent.OdometerData` (`job_event/odometer_data.ex`) for the fields it accepts before deciding. This affects costing (`realized_cost` is computed from JobEvents).
- **Costing impact:** `realized_cost` is derived from JobEvents with staff rate snapshots and stored when the job is marked `:complete`. An ad-hoc departure job should still flow through that path so it costs correctly.
- "Pick a new garden on the fly" (J2/J3 garden picker) should reuse the H2 add-garden flow so an ad-hoc visit to a brand-new site is possible.

---

## Design tokens — DARK THEME (build from these)
These are the actual values from `Login Polished.html`. Add them to the Tailwind theme
(`assets/tailwind.config.js` / CSS custom properties) and build dark-first. The light variant
in `Login Polished (light).html` exists only for reference/comparison — the product ships dark.

### Color
| Token | Hex | Use |
|-------|-----|-----|
| `bg/page` | `#0E0D08` | outermost app backdrop (warm near-black) |
| `soil` (screen bg) | `#16140E` | primary screen background |
| `surface` | `#211E16` | raised cards, inputs |
| `surface-2` | `#2B2820` | hover / chips / deeper fills |
| `border` | `#343025` (≈60% opacity warm) | hairline borders |
| `ink` | `#F4EFE2` | primary text (warm off-white) |
| `ink-strong` | `#CFC8B8` | strong secondary text |
| `ink-muted` | `#9A9384` | muted / meta text |
| `ink-faint` | `#6E675A` | placeholders, disabled |
| `forest` | `#1C4631` → `#0E2419` | brand hero panel gradient |
| `leaf` (primary) | `#54B57E` | primary buttons, active accents |
| `leaf-bright` | `#6BCB93` | hover state of primary |
| `leaf-wash` | `rgba(84,181,126,0.14)` | soft green fills, badges |
| `on-leaf` | `#0C1F15` | **text/icons on green buttons** (dark, for the "lit" pop) |
| `amber` | `#DB9258` | role accent — **Owner** |
| `amber-wash` | `rgba(219,146,88,0.16)` | amber pill background |
| `ring` | `rgba(84,181,126,0.30)` | input focus ring |

### Type
- **Display / wordmark / headings:** Bricolage Grotesque (700–800), letter-spacing `-0.02em`.
- **UI / body:** Hanken Grotesk (400–700).
- Scale (px): wordmark 27 · screen H1 23–25 · greeting 27 · body 14.5–15 · label 13 · meta 12.5 · micro 11.5.
- Both are on Google Fonts. If the app prefers self-hosted fonts, mirror these or pick the closest licensed equivalents and keep the grotesk character.

### Spacing, radius, shadow, ergonomics
- **Screen padding:** 24–30px. **Card padding:** 15–16px. **Card gap:** 12px.
- **Radius:** buttons & inputs 14–16px · cards 18px · brand/monogram tiles 14px · phone screen 36px.
- **Touch targets:** primary actions and inputs are **56px tall**; icon buttons 40px. Keep ≥44px everywhere (gloved hands).
- **Shadow:** soft, dark — `0 1px 2px rgba(0,0,0,.4), 0 12px 30px rgba(0,0,0,.45)` for cards; a faint green glow `0 6px 20px rgba(84,181,126,.30)` on the primary button.
- **Focus:** 4px `ring` glow + `leaf` border on inputs.
- **Role pills:** Field crew → `leaf-wash`/`leaf`; Owner → `amber-wash`/`amber`; Supplier → `surface-2`/`ink-muted`.

> Rationale to preserve: **low-glare dark**, high legibility, large targets, one growlight-green primary per screen, amber reserved strictly for ownership/roles. A single sprout glyph is the logo — no decorative illustration.

## Screens / artboard index
All screens live in `Mobile-First Wireframes.html`, laid out on a pan/zoom canvas. The new
sections from this round:
- **L1–L3** — Login & onboarding
- **H1–H3** — Customer creation
- **I1–I2** — Customers (list + summary)
- **K1–K2** — Job creation (planned)
- **J1–J3** — Ad-hoc job
Earlier sections (A · Today/feed, B–G · jobs/engagements/inventory/shift flows) are also in
the file for context. Toggle the "annotated" tweak to show/hide the rationale callouts.

## Files in this bundle
- `Login Polished.html` — **HIGH-FIDELITY** mockup of the L flow (L1–L3) in the final dark theme. Visual source of truth for Section L; token reference for all sections. Open in a browser.
- `Login Polished (light).html` — light-theme variant of the same, for reference only (the product ships dark).
- `Jobs Polished.html` — **HIGH-FIDELITY** mockup of the Jobs tab list + the polished bottom nav. Visual source of truth for the Jobs list and the nav bar.
- `Mobile-First Wireframes.html` — the low-fi wireframe canvas for all sections (open in a browser)
- `wireframe-screens.jsx` — all wireframe screen definitions (search `ScreenL1`, `ScreenH1`, `ScreenI1`, `ScreenJ1`, …)
- `wireframe-ui.jsx` — the hand-drawn primitive components + tokens
- `design-canvas.jsx`, `tweaks-panel.jsx` — canvas + tweak-panel scaffolding (not product code)

## Suggested build order
1. Bottom-nav shell + mobile layout wrappers (Section 0) — unblocks everything else.
2. Login/org (Section L) — mostly redress of existing `OrgPickLive`/`OrgNewLive` + zero-membership branch.
3. Customer create + summary (H, I) — add the single-billing invariant to the `Customer` action.
4. Job creation (K) — the foundational create flow; reuse `job_live/form_component.ex` logic + add multi-crew (`JobStaff`) assignment and the live `estimated_cost`.
5. Ad-hoc job (J) — the unplanned special case of K. Define "active job", add the gate, reuse event + materials components.

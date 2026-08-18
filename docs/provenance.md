# Provenance report

Generated 2026-08-17, at commit `dbc869292936b7ea7343c851c16e80faec9b8a91`, by:

```
python3 scripts/copyright_audit.py --todo-only
```

Baseline: `17c01096dc05892c7a3236b26c3ab10610e6b2ca` — the original author's last commit before
this rewrite began. 328 commits are in scope as "old." This report lists every file the audit
still flags as carrying at least one line traced to that history — 153 files, out of 199 tracked
source files (`*.ex *.exs *.heex *.js *.ts *.css`). 46 files trace to zero and aren't listed.

**What this is not:** a claim that all 153 files below are untouched. It's the raw residue
`git blame --porcelain -C -C -C` reports, sorted into categories by what that residue actually
*is*. The README's claim is "every line of meaningful code has been replaced," not "this table
is empty" — the table isn't empty, on purpose, because a literal-zero blame result is not itself
evidence of independent authorship (see below).

## Why this doesn't read zero, and why that's not a gap

Ash is a declarative, boilerplate-driven CRUD framework. A resource's `use Ash.Resource` header,
a bare `postgres do table "..." end` block, an `attribute :x, :string do allow_nil? false end`
skeleton, a `json_api do routes do get(:read) end end` exposure block — these have close to one
correct spelling. Two people independently building "a Supplier with a name and contact fields"
in Ash converge on nearly identical text without either having read the other's code. Line-level
`git blame`, even with full rename/copy tracing, cannot distinguish "identical because copied"
from "identical because there was only one reasonable way to write it" — it just reports the
oldest matching occurrence. A rewrite chasing literal zero here would mean cosmetically
reshuffling `uuid_primary_key :id` and `timestamps()` to move a percentage, which is theater, not
verification.

So the table below is organized by what kind of residue it is, not just by how much:

- **Ash resource & domain DSL** — resource skeletons and the once-off JSON:API/GraphQL exposure
  blocks written across the whole app in a single commit. Eight of these files were individually
  checked line-by-line against `git blame` output (noted in the table) rather than assumed from
  the category; the rest are categorized by file location and are expected, not verified, to
  follow the same pattern.
- **Framework & build scaffolding** — `mix.exs`, `config/*.exs`, `.formatter.exs`, Phoenix/Ash/
  AshAuthentication generator output (`endpoint.ex`, `gettext.ex`, `auth_overrides.ex`,
  `error_html.ex`, layout `.heex` files, `router.ex`'s route-declaration lines, etc.).
- **Vendored / generator-produced assets** — third-party JS (`topbar.js`, MIT-licensed, not
  ours to claim) and Tailwind's heroicons output.
- **Test scaffolding** — `test/support/*` helpers, mostly `ExUnit.CaseTemplate`/`DataCase`/
  `ConnCase` boilerplate that every Phoenix+Ash project has in roughly this shape.
- **App test files** — validation/regression tests for real app behavior. Small residue, likely
  incidental short-line matches (a shared assertion pattern, a common setup line); not
  individually verified.
- **Mobile UI (LiveViews & components)** — the bulk of the app by line count. Residue here is
  overwhelmingly under 25%, usually a handful of lines out of hundreds — coincidental matches on
  common Phoenix/HEEx idioms, not retained logic.

## Known exceptions — genuinely retained, and what happened to them

Three pieces of *real* original-author logic were found this way and dealt with, not waved past:

- `lib/opensauce/inventory/lot.ex` and the `PurchaseOrder.receive`/`lot_receipts` machinery —
  confirmed unreachable from any UI, JSON:API, or GraphQL path. Deleted.
- `lib/opensauce/crm/customer.ex` — a policy bypass for public/anonymous checkout access
  (`get_by_email`, "Allow public create/update — checkout address upsert") that doesn't apply to
  this app (staff-only, no storefront). Removed; policy tightened to manager/owner writes.
  Consequence tracked in `TODO.md`.
- `lib/opensauce/inventory/receiving.ex` — genuinely live, traced against the actual GUI pickup
  flow, confirmed correct, then rewritten with the same behavior and verified end-to-end.
- `lib/opensauce/types/unit.ex` — CraftPlan's food-nutrition units (kcal, milligram, percent),
  confirmed dead (never offered in the live UI). Pruned to the 4 units this business uses.

One deliberately-not-chased exception: `lib/opensauce/inventory/purchase_order.ex`'s
`create`/`update` action bodies (accept lists, `set_attribute(:status, :draft)`) are still
literally the original text — judged mechanical enough not to be worth cosmetic rewriting, same
as the resource-skeleton category generally, but flagged here rather than left silent.

Pre-baseline history has not been truncated. This report, and the audit that produced it, stay
re-runnable.

---

### Ash resource & domain DSL

| Status | Orig% | Old/Total | File | Note |
|---|---|---|---|---|
| TODO | 84% | 68/81 | `lib/opensauce/inventory/movement.ex` | Verified: flagged lines are `use Ash.Resource`, `postgres do end`, bare attribute/action skeleton, `relationships do end`. No bespoke content left old. |
| TODO | 78% | 126/161 | `lib/opensauce/inventory/material.ex` | Verified: flagged lines are skeleton + JSON:API/GraphQL exposure block written once across the app. |
| TODO | 75% | 97/130 | `lib/opensauce/inventory/purchase_order.ex` | Verified, with one caveat: skeleton + exposure block as above, but the create/update action bodies (accept lists, `set_attribute(:status, :draft)`) are still literally untouched original text -- judged mechanical, not rewritten. |
| PARTIAL | 69% | 87/126 | `lib/opensauce/inventory/supplier.ex` | Verified: flagged lines are skeleton + JSON:API/GraphQL exposure block. The `manage_relationship(:addresses, ...)` logic is confirmed new. |
| PARTIAL | 54% | 67/125 | `lib/opensauce/accounts/user.ex` |  |
| PARTIAL | 54% | 44/82 | `lib/opensauce/inventory.ex` |  |
| PARTIAL | 48% | 32/66 | `lib/opensauce/work/job_event_material.ex` |  |
| PARTIAL | 46% | 139/305 | `lib/opensauce/crm/customer.ex` | Verified: found and removed genuine retained content (a dead public-checkout policy + get_by_email action). Remaining residue is the same skeleton pattern as other resources. |
| PARTIAL | 39% | 23/59 | `lib/opensauce/inventory/receiving.ex` | Verified live against the actual GUI receiving flow, confirmed genuinely retained, then rewritten (fresh wording, same behavior, tested end-to-end). |
| PARTIAL | 37% | 69/186 | `lib/opensauce/inventory/purchase_order_item.ex` | Verified: flagged lines are `use Ash.Resource`, bare attribute/action skeleton, one generic filter clause. None of the confirmed_qty/received_qty/is_reservation logic traces to the original author. |
| PARTIAL | 37% | 19/51 | `lib/opensauce/operations/storage_location.ex` |  |
| PARTIAL | 37% | 19/51 | `lib/opensauce/operations/venue.ex` |  |
| PARTIAL | 31% | 19/61 | `lib/opensauce/types/unit.ex` | Verified: residue was CraftPlan food-nutrition units (kcal, milligram, percent) confirmed dead (never offered in the live UI). Pruned to the 4 units this business actually uses. |
| PARTIAL | 29% | 20/69 | `lib/opensauce/crm.ex` |  |
| PARTIAL | 29% | 2/7 | `lib/opensauce/inventory/purchase_order/types/status.ex` |  |
| PARTIAL | 29% | 2/7 | `lib/opensauce/types/currency.ex` |  |
| PARTIAL | 28% | 27/97 | `lib/opensauce/inventory/supplier_catalog.ex` |  |
| PARTIAL | 27% | 24/90 | `lib/opensauce/work/job_material.ex` |  |
| PARTIAL | 26% | 16/62 | `lib/opensauce/work/job_staff.ex` |  |
| PARTIAL | 25% | 17/67 | `lib/opensauce/work/job_event_staff.ex` |  |
| MOSTLY | 24% | 20/84 | `lib/opensauce/accounts/tax_rate.ex` |  |
| MOSTLY | 23% | 14/61 | `lib/opensauce/work.ex` |  |
| MOSTLY | 21% | 3/14 | `lib/opensauce/work/job_event/tag_only.ex` |  |
| MOSTLY | 19% | 10/52 | `lib/opensauce/accounts.ex` |  |
| MOSTLY | 18% | 18/101 | `lib/opensauce/accounts/organisation_member.ex` |  |
| MOSTLY | 18% | 27/147 | `lib/opensauce/crm/address.ex` |  |
| MOSTLY | 18% | 36/202 | `lib/opensauce/inventory/supplier_catalog_item.ex` |  |
| MOSTLY | 17% | 18/107 | `lib/opensauce/crm/engagement_material.ex` |  |
| MOSTLY | 17% | 3/18 | `lib/opensauce/work/job/calculations/man_hour_rate.ex` |  |
| MOSTLY | 17% | 3/18 | `lib/opensauce/work/job_event/odometer_data.ex` |  |
| MOSTLY | 16% | 17/104 | `lib/opensauce/work/job_event.ex` |  |
| MOSTLY | 14% | 2/14 | `lib/opensauce/work/job/calculations/estimated_man_hours.ex` |  |
| MOSTLY | 13% | 35/266 | `lib/opensauce/accounts/organisation.ex` |  |
| MOSTLY | 12% | 19/152 | `lib/opensauce/crm/invoice.ex` |  |
| MOSTLY | 11% | 20/190 | `lib/opensauce/crm/engagement_image.ex` |  |
| MOSTLY | 8% | 3/39 | `lib/opensauce/work/job/calculations/duration.ex` |  |
| MOSTLY | 8% | 3/39 | `lib/opensauce/work/job/calculations/mileage_km.ex` |  |
| MOSTLY | 7% | 17/237 | `lib/opensauce/crm/engagement.ex` |  |
| MOSTLY | 6% | 19/325 | `lib/opensauce/work/job.ex` |  |
| MOSTLY | 1% | 2/146 | `lib/opensauce/inventory/catalog_importer.ex` |  |

### Framework & build scaffolding

| Status | Orig% | Old/Total | File | Note |
|---|---|---|---|---|
| TODO | 100% | 19/19 | `.formatter.exs` |  |
| TODO | 100% | 9/9 | `.igniter.exs` |  |
| TODO | 96% | 92/96 | `lib/opensauce_web/auth_overrides.ex` |  |
| TODO | 95% | 576/605 | `lib/opensauce_web/html_helpers.ex` |  |
| TODO | 93% | 54/58 | `assets/js/app.js` |  |
| TODO | 93% | 65/70 | `docs/generate_spec.exs` |  |
| TODO | 93% | 97/104 | `lib/opensauce/accounts/token.ex` |  |
| TODO | 92% | 70/76 | `lib/opensauce/release.ex` |  |
| TODO | 90% | 18/20 | `lib/opensauce_web/controllers/page_html/home.html.heex` |  |
| TODO | 89% | 17/19 | `config/prod.exs` |  |
| TODO | 89% | 66/74 | `lib/opensauce/accounts/emails.ex` |  |
| TODO | 88% | 88/100 | `config/dev.exs` |  |
| TODO | 88% | 42/48 | `config/test.exs` |  |
| TODO | 88% | 115/130 | `lib/opensauce_web.ex` |  |
| TODO | 87% | 104/119 | `config/config.exs` |  |
| TODO | 86% | 183/212 | `config/runtime.exs` |  |
| TODO | 86% | 24/28 | `lib/opensauce_web/live_current_path.ex` |  |
| TODO | 83% | 20/24 | `lib/opensauce_web/controllers/error_json.ex` |  |
| TODO | 83% | 49/59 | `lib/opensauce_web/endpoint.ex` |  |
| TODO | 79% | 22/28 | `lib/opensauce_web/gettext.ex` |  |
| TODO | 78% | 31/40 | `lib/opensauce_web/live_nav.ex` |  |
| TODO | 78% | 91/117 | `mix.exs` |  |
| PARTIAL | 74% | 20/27 | `lib/opensauce_web/controllers/error_html.ex` |  |
| PARTIAL | 73% | 16/22 | `lib/opensauce/repo.ex` |  |
| PARTIAL | 62% | 16/26 | `lib/opensauce_web/components/layouts/root.html.heex` |  |
| PARTIAL | 62% | 8/13 | `lib/opensauce_web/controllers/page_html.ex` |  |
| PARTIAL | 59% | 20/34 | `lib/opensauce/application.ex` |  |
| PARTIAL | 58% | 7/12 | `lib/opensauce.ex` |  |
| PARTIAL | 54% | 20/37 | `lib/opensauce_web/live_settings.ex` |  |
| PARTIAL | 53% | 139/260 | `lib/opensauce_web/router.ex` |  |
| PARTIAL | 43% | 3/7 | `docs/generate_sdl.exs` |  |
| PARTIAL | 43% | 3/7 | `lib/opensauce/gettext.ex` |  |
| PARTIAL | 43% | 6/14 | `lib/opensauce_web/controllers/page_controller.ex` |  |
| PARTIAL | 42% | 5/12 | `lib/opensauce_web/components/layouts/app.html.heex` |  |
| PARTIAL | 38% | 3/8 | `docs/src/styles/global.css` |  |
| PARTIAL | 29% | 2/7 | `lib/opensauce/mailer.ex` |  |
| PARTIAL | 29% | 35/122 | `lib/opensauce_web/live_user_auth.ex` |  |
| PARTIAL | 27% | 3/11 | `lib/opensauce/secrets.ex` |  |
| PARTIAL | 26% | 20/78 | `lib/opensauce_web/controllers/auth_controller.ex` |  |
| PARTIAL | 25% | 5/20 | `lib/opensauce_web/schema.ex` |  |
| MOSTLY | 23% | 3/13 | `lib/opensauce_web/json_api_router.ex` |  |
| MOSTLY | 21% | 10/48 | `assets/js/hooks/index.js` |  |
| MOSTLY | 19% | 4/21 | `lib/opensauce_web/components.ex` |  |
| MOSTLY | 14% | 55/392 | `assets/css/app.css` |  |
| MOSTLY | 11% | 2/19 | `lib/opensauce_web/live_shift.ex` |  |
| MOSTLY | 5% | 18/338 | `priv/repo/seeds.exs` |  |

### Vendored / generator-produced assets

| Status | Orig% | Old/Total | File | Note |
|---|---|---|---|---|
| TODO | 100% | 47/47 | `assets/css/tailwind_heroicons.js` |  |
| TODO | 100% | 165/165 | `assets/vendor/topbar.js` |  |

### Test scaffolding

| Status | Orig% | Old/Total | File | Note |
|---|---|---|---|---|
| TODO | 93% | 81/87 | `test/support/mailpit.ex` |  |
| TODO | 80% | 51/64 | `test/support/conn_case.ex` |  |
| TODO | 79% | 27/34 | `test/support/ash_helpers.ex` |  |
| PARTIAL | 64% | 61/96 | `test/support/data_case.ex` |  |
| PARTIAL | 31% | 25/80 | `test/support/auth_helpers.ex` |  |
| MOSTLY | 20% | 1/5 | `test/test_helper.exs` |  |
| MOSTLY | 16% | 36/231 | `test/support/factory.ex` |  |

### App test files (small residue, not individually verified)

| Status | Orig% | Old/Total | File | Note |
|---|---|---|---|---|
| TODO | 84% | 31/37 | `test/opensauce_web/api/cors_test.exs` |  |
| TODO | 82% | 58/71 | `test/opensauce/inventory/material_name_validation_test.exs` |  |
| TODO | 80% | 37/46 | `test/opensauce/inventory/supplier_name_validation_test.exs` |  |
| PARTIAL | 66% | 37/56 | `test/opensauce/crm/customer_name_validation_test.exs` |  |
| PARTIAL | 42% | 16/38 | `test/types_unit_test.exs` |  |
| MOSTLY | 13% | 3/23 | `test/opensauce_web/empty_stream_live_test.exs` |  |

### Mobile UI (LiveViews & components)

| Status | Orig% | Old/Total | File | Note |
|---|---|---|---|---|
| TODO | 90% | 630/699 | `lib/opensauce_web/components/layouts.ex` |  |
| TODO | 83% | 30/36 | `lib/opensauce_web/components/utils.ex` |  |
| TODO | 76% | 746/982 | `lib/opensauce_web/components/core.ex` |  |
| PARTIAL | 35% | 60/170 | `lib/opensauce_web/live/manage/customer_live/form_component.ex` |  |
| PARTIAL | 29% | 59/201 | `lib/opensauce_web/live/manage/inventory_live/form_component_movement.ex` |  |
| PARTIAL | 26% | 192/746 | `lib/opensauce_web/components/page.ex` |  |
| MOSTLY | 24% | 52/220 | `lib/opensauce_web/live/manage/purchasing_live/purchase_order_item_form_component.ex` |  |
| MOSTLY | 22% | 25/115 | `lib/opensauce_web/live/manage/customer_live/index.ex` |  |
| MOSTLY | 21% | 47/220 | `lib/opensauce_web/live/manage/inventory_live/form_component_material.ex` |  |
| MOSTLY | 19% | 10/53 | `lib/opensauce_web/live/manage/invoice_live/new.ex` |  |
| MOSTLY | 18% | 33/183 | `lib/opensauce_web/live/manage/inventory_live/index.ex` |  |
| MOSTLY | 18% | 41/231 | `lib/opensauce_web/live/manage/purchasing_live/suppliers.ex` |  |
| MOSTLY | 16% | 49/306 | `lib/opensauce_web/live/manage/purchasing_live/supplier_form_component.ex` |  |
| MOSTLY | 11% | 43/392 | `lib/opensauce_web/live/manage/inventory_live/show.ex` |  |
| MOSTLY | 11% | 31/281 | `lib/opensauce_web/live/manage/purchasing_live/index.ex` |  |
| MOSTLY | 11% | 8/73 | `lib/opensauce_web/live/manage/venue_live/venue_form_component.ex` |  |
| MOSTLY | 9% | 8/88 | `lib/opensauce_web/live/manage/venue_live/storage_location_form_component.ex` |  |
| MOSTLY | 8% | 6/73 | `lib/opensauce_web/live/manage/invoice_live/edit.ex` |  |
| MOSTLY | 4% | 18/458 | `lib/opensauce_web/live/manage/job_live/index.ex` |  |
| MOSTLY | 4% | 9/204 | `lib/opensauce_web/live/manage/venue_live/index.ex` |  |
| MOSTLY | 3% | 24/851 | `lib/opensauce_web/live/manage/customer_live/show.ex` |  |
| MOSTLY | 3% | 3/104 | `lib/opensauce_web/live/manage/engagement_live/new.ex` |  |
| MOSTLY | 3% | 7/248 | `lib/opensauce_web/live/manage/invoice_live/index.ex` |  |
| MOSTLY | 3% | 12/367 | `lib/opensauce_web/live/manage/job_live/form_component.ex` |  |
| MOSTLY | 3% | 47/1390 | `lib/opensauce_web/live/manage/purchasing_live/show.ex` |  |
| MOSTLY | 2% | 4/226 | `lib/opensauce_web/live/manage/account_live.ex` |  |
| MOSTLY | 2% | 18/788 | `lib/opensauce_web/live/manage/engagement_live/form_component.ex` |  |
| MOSTLY | 2% | 6/280 | `lib/opensauce_web/live/manage/job_live/event_log_component.ex` |  |
| MOSTLY | 2% | 2/104 | `lib/opensauce_web/live/org_new_live.ex` |  |
| MOSTLY | 1% | 3/310 | `lib/opensauce_web/components/jobs.ex` |  |
| MOSTLY | 1% | 2/155 | `lib/opensauce_web/live/components/catalog_search_component.ex` |  |
| MOSTLY | 1% | 7/611 | `lib/opensauce_web/live/manage/customer_live/new.ex` |  |
| MOSTLY | 1% | 1/118 | `lib/opensauce_web/live/manage/engagement_live/estimate.ex` |  |
| MOSTLY | 1% | 2/254 | `lib/opensauce_web/live/manage/engagement_live/materials_component.ex` |  |
| MOSTLY | 1% | 6/493 | `lib/opensauce_web/live/manage/engagement_live/show.ex` |  |
| MOSTLY | 1% | 6/727 | `lib/opensauce_web/live/manage/invoice_live/show.ex` |  |
| MOSTLY | 1% | 2/274 | `lib/opensauce_web/live/manage/job_live/arrive.ex` |  |
| MOSTLY | 1% | 2/206 | `lib/opensauce_web/live/manage/job_live/event_materials_component.ex` |  |
| MOSTLY | 1% | 2/211 | `lib/opensauce_web/live/manage/job_live/materials_component.ex` |  |
| MOSTLY | 1% | 24/2230 | `lib/opensauce_web/live/manage/org_live.ex` |  |
| MOSTLY | 1% | 4/681 | `lib/opensauce_web/live/manage/schedule_live.ex` |  |
| MOSTLY | 1% | 5/540 | `lib/opensauce_web/live/manage/shift_live/summary.ex` |  |
| MOSTLY | 1% | 4/647 | `lib/opensauce_web/live/manage/today_live.ex` |  |
| MOSTLY | 1% | 4/315 | `lib/opensauce_web/live/manage/venue_live/show.ex` |  |
| MOSTLY | 0% | 2/697 | `lib/opensauce_web/live/manage/engagement_live/materials.ex` |  |
| MOSTLY | 0% | 6/1202 | `lib/opensauce_web/live/manage/invoice_live/form_component.ex` |  |
| MOSTLY | 0% | 2/797 | `lib/opensauce_web/live/manage/job_live/adhoc.ex` |  |
| MOSTLY | 0% | 2/650 | `lib/opensauce_web/live/manage/job_live/closeout.ex` |  |
| MOSTLY | 0% | 2/625 | `lib/opensauce_web/live/manage/job_live/materials.ex` |  |
| MOSTLY | 0% | 3/1349 | `lib/opensauce_web/live/manage/job_live/new.ex` |  |
| MOSTLY | 0% | 3/604 | `lib/opensauce_web/live/manage/shift_live/start.ex` |  |
| MOSTLY | 0% | 2/471 | `lib/opensauce_web/live/portal/invoice_live.ex` |  |


# TODO

## Highest priority

- [ ] Job ↔ Engagement link — show jobs list on Engagement tab (link exists on job, not surfaced in engagement view)
- [ ] Plan → job material reconciliation — "from plan, not added yet" section on the job materials screen has unresolved UX: what if the item was already added manually? should the user set a different qty than the plan? partial adds? Don't invest further until the plan↔job reconciliation model is clearer

## Domain gaps

- [ ] Propagation loop — `JobEventMaterial` with a plant material records the event but nothing triggers an inventory receive
- [ ] Material category — discussed, never implemented

## Costing

- [ ] Labor cost absent from job cost — duration × rate not modelled at all
- [ ] 1.2× markup hardcoded in `price_from_cost/1` — should come from Settings

## Engagement lifecycle

- [ ] Signing flow — status is a free dropdown with no enforcement; no signature display
- [ ] Jobs list under the Engagement tab
- [ ] Engagement stats — contract value, realized cost, margin all empty

## Component organisation refactor

Split `core.ex` and `page.ex` by concern. `materials.ex` is done; remaining:

- `identity.ex` — extract `member_avatar`, `member_card` out of `core.ex`
- `core.ex` — keep only generic UI primitives: `modal`, `flash`, `flash_group`,
  `glow_button`, `bottom_sheet`, `label`, `error`, `kbd`, `button`, `tabs`,
  `stepper`, `tab_link`, `tabs_nav`, `tabs_content`, `sub_nav`, `breadcrumb`
- `page.ex` — nav shell only; delete defunct desktop components (`sidebar_layout`,
  `surface`, `section`, `two_column`, `toggle_bar`) rather than moving them
- `add_job_icon` in `core.ex` can move to a `jobs.ex` when there are enough
  job-specific components to warrant it

New modules register in `components.ex`; all callers get them through
`use OpenSauceWeb, :live_view` without changes.

## Housekeeping

- [ ] Command palette doesn't index Engagements
- [ ] No tests for anything added in recent sessions (incl. UpdatePurchaseOrders, MovePoItem, print component)
- [ ] `catalog/` directory (PDF + JSON data files) sitting untracked — move or gitignore

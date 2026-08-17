# OpenSauce Dirt

A self-hosted ERP for small landscaping and gardening businesses: client engagements, field job scheduling, crew costing, materials inventory, purchasing, and invoicing.

It is also the artifact of a deliberate experiment — minimally steered LLM development in a language and framework I did not know when I started, over roughly two months. It runs a real business every day. The code is mediocre. Both of those are the result, and the second one is not an apology.

## What it does

Built around the operational loop of a landscaping outfit: **engagement → jobs → job events → invoice**, with costs captured at the point of work rather than reconstructed afterwards.

- **Engagements** — contract lifecycle, install/maintenance pricing, signature capture, attached photos and garden paintings
- **Jobs and shifts** — client work, internal work, and shift containers holding child jobs; tentative crew assignment drives calendar and estimate
- **Crew costing** — job events log arrival/departure with the crew actually present and their rates snapshotted at log time; realised cost accumulates across multiple visits and is frozen at completion
- **Inventory** — materials tracked as lots through receive/consume/adjust movements, across venues and storage locations
- **Purchasing** — suppliers, purchase orders, and supplier catalogue import
- **Invoicing** — Typst-rendered invoices and batch sheets
- **Multi-tenant** — attribute multitenancy on `organisation_id` across every resource, with Ash policies and tenant-isolation tests
- **Integration surface** — GraphQL, JSON:API with an OpenAPI spec, scoped API keys, an iCal feed for job schedules, CSV export

The UI is a dark-first **mobile field app**. There is no desktop product; screens are built for a phone held in a garden, not a laptop in an office.

**Stack:** Elixir · Ash Framework · Phoenix LiveView · PostgreSQL 18 · Tailwind · Typst · Nix

## The experiment

The premise was not "can an LLM write code" — obviously it can — but "what does the code look like when the human declines to impose taste on it, and has no taste to impose in the first place?"

Most reports of AI-assisted development come from people working in a stack they already know well, where the human silently corrects direction on every turn: rejecting a bad module boundary before it lands, rewriting a function because it smells, reaching for the idiomatic library without ever asking. That steering is invisible in the transcript and enormous in the output. To measure what the machine contributes unaided, the steering has to go — and the reliable way to remove it is to pick a stack where you have nothing to steer with.

**Conditions:**

- **Unfamiliar stack as the control.** Elixir, Phoenix, and Ash, none of which I had written before. Ash especially: a declarative framework with strong opinions, where a newcomer's instincts are worth nothing and the model's exposure to the documentation is worth something. Choosing it removed my ability to steer on craft even had I wanted to.
- **Human direction confined to policy.** Two rules in `CLAUDE.md` are mine. *Mobile only* is a business decision — the users are in gardens. *The testing policy* — no CRUD tests, only validations, authorization, tenant isolation, and structural regressions — is how I actually work, and under generation it is also a budget decision: tests against a model still being sketched cost time and tokens and catch nothing. Everything else in `CLAUDE.md` and `AGENTS.md`, including the architecture description and the Ash conventions, was written by the model about its own work.
- **No hand rescue.** The output was not quietly refactored into something I liked afterwards. Doing that would have destroyed the measurement.
- **Ship it anyway, and operate it.** An experiment you never have to live with teaches you nothing.

The repository was spun from a template. Every line of the original author's code has since been replaced — verified rather than assumed, with `scripts/copyright_audit.py`, which walks `git blame` with full rename and copy tracing (`-C -C -C`) against the baseline commit and reports per-file what fraction still traces to pre-baseline commits. It was driven to zero before the pre-baseline history was truncated.

## What it produced

**The code is mediocre in a specific way: it is correct and illegible.** The problem is not that it does the wrong thing. It is that no one could read it and work on it comfortably, including me.

- **Accretion instead of decomposition.** `org_live.ex` is 2,230 lines; `purchasing_live/show.ex` is 1,390; `job_live/new.ex` is 1,325. Modules grow; they do not get split.
- **Presentation smeared everywhere.** The same utility-class blocks are re-embedded inline across templates instead of being extracted into components. Overrides are scattered rather than grouped. Nothing in the loop feels the friction of the fourth repetition, so nothing ever refactors it.
- **Roughly 36,000 lines under `lib/` in two months.** That throughput is exactly what buys the illegibility. It is the trade, stated plainly.
- **Documentation drifts from the code.** `CLAUDE.md` still describes an `OpenSauce.Orders` domain; the module is `OpenSauce.Work`. It documents a legacy `settings_live/` tree that no longer exists. A steering file generated and maintained by the same loop decays exactly the way the code does, and nothing notices.
- **Known gaps are catalogued, not hidden.** `TODO.md` carries the honest list: labour cost is absent from job costing entirely, a 1.2× markup is hardcoded where a setting belongs, the engagement signing flow has no enforcement.

I would not ship this to a client. I ship it to myself.

**It is also sufficient.** It manages a going concern, correctly, daily. Mediocre code that runs a business is a different object from mediocre code that fails, and that distinction matters more than the aesthetic complaint. What it does not clear is the bar for anything with clients, a team, or a maintenance horizon longer than my patience.

## Where the human judgement actually went

The interesting result is not the code quality. It is that judgement did not disappear when it was withheld from the application code — it relocated to the operating envelope, which is where it was load-bearing.

- **Reproducible builds.** Nix-defined container images for app, PostgreSQL, and Caddy, built via [krump](https://github.com/serverplumber/krump). When generated code does something surprising, the environment is not also a variable.
- **No registry in the path.** The dev machine builds the image and streams it to the VPS over ssh. Fewer moving parts, no third-party availability in the deploy path.
- **Preprod and prod on the same host**, as separate podman pods on separate ports, so a release is exercised before it touches real data.
- **Data moves one way, anonymised.** Code goes dev → VPS. Data returns VPS → dev only after being anonymised *on the VPS*; raw PII never lands on a development machine. Encrypted attributes at rest via Cloak.
- **Provenance verified, not asserted.** The copyright audit above exists because "I rewrote all of it" is a claim, and claims about code should be checkable.
- **Blast radius chosen up front.** One business — mine to answer for, not a client's. One VPS at roughly $10/month, plus mail and domains. One operator who knew going in that he would be babysitting it.

That is the finding. Minimally steered generation is an acceptable technique at exactly this scale, and it is acceptable *because* the judgement withheld from the code was spent on containment instead.

## Running it

```bash
mix setup          # deps, ash.setup, assets, seeds
just up            # dev PostgreSQL 18 via podman
mix phx.server     # localhost:4000
```

`mix ash.codegen <name>` after any resource change — commit the migration and the snapshot together. Deployment lives in `prod/README.md`; agent-facing conventions in `AGENTS.md` and `CLAUDE.md`.

## What this is not

- Not a product, not a template, not something to run your business on.
- Not an argument that AI-assisted development is good or bad. It is one run with the human contribution deliberately suppressed in one place and concentrated in another, which is not how anyone should work by default — it is how you find out what the suppressed variable was worth.
- Not maintained for anyone else. Issues and PRs are unlikely to get a response.

## Status

v0.5.0. In production. Source-available under the Elastic License 2.0 — see `LICENSE`; this is not an OSI open-source licence.

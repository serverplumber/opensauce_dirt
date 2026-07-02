---
layout: ../../layouts/DocsLayout.astro
title: Deployment & Data Lifecycle
description: How code moves forward to production and data moves back to development
---

## The two flows

There are two directions of movement in this system and they never swap:

```
code   →  dev  →  preprod  →  prod
data   ←  dev  ←  preprod  ←  prod
```

Code is promoted forward through environments. Production data is anonymised and pulled backward so developers always have realistic data to work with.

---

## Environments

| Environment | Port | Purpose |
|---|---|---|
| **dev** | 4000 | Local machine. Runs via `just up` + `just dev`. |
| **preprod** | 4001 | Staging pod on the production host. Mirrors prod infrastructure. Receives anonymised prod data. |
| **prod** | 4000 | Live. Managed exclusively from `prod/`. |

Preprod and prod run as podman pods on the same host. Both are managed from `prod/` — all commands default to preprod, and `env=prod` must be written explicitly to target production.

---

## Promoting code

### Dev → preprod

Build the prod image and start preprod:

```bash
just prod-build
just start               # targets preprod by default
just migrate
```

Verify the build behaves correctly against real (anonymised) data before touching prod.

### Preprod → prod

Once verified on preprod:

```bash
just stop    env=prod
just destroy env=prod
just start   env=prod
just migrate env=prod
```

The image is the same binary that ran on preprod. No rebuild between environments.

---

## Moving data back to dev

Production data contains real customer names, addresses, and contact details. Before it can be used in development it must be anonymised. This is an operator task — developers never see raw production data.

### What gets anonymised

| Table | Fields replaced |
|---|---|
| `crm_customers` | first/last name, company name, email, phone |
| `crm_addresses` | street, city, province, postal code, notes, coordinates |
| `accounts_users` | first/last name, email |
| `accounts_organisations` | phone, payment info, all contact fields |
| `accounts_tokens` | truncated entirely |

Organisation name is preserved so developers have meaningful context. All replaced values are structurally valid (unique emails, formatted phone numbers).

### Operator: populate preprod with anonymised prod data

One command does the full pipeline — dumps prod, restores to preprod, anonymises in place:

```bash
cd prod
just anon-from-prod
```

### Developer: load anonymised data locally

Once preprod has been populated, a developer can pull the latest anonymised backup and load it into their local database:

```bash
# On the production host — give the developer this file
ls -lh prod/backups/

# On the developer's machine
just down    # stop local postgres if running
just up      # start fresh
# restore via psql directly against the local container:
gunzip -c opensauce_20260702_120000.sql.gz | \
  podman exec -i opensauce-postgres psql -U postgres opensauce_dev
just server
```

---

## Routine operator checklist

**On every deploy:**

```bash
cd prod
just backup                  # always take a backup before touching anything
just stop    env=prod
just destroy env=prod
just build
just start   env=prod
just migrate env=prod
just logs    env=prod        # watch for startup errors
```

**Periodically (or before a big dev sprint):**

```bash
cd prod
just anon-from-prod          # refresh preprod with fresh anonymised prod data
```

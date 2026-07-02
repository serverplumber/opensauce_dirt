# Production

Self-contained production tooling. The only things you need on the host are
`podman` and `just`.

---

## Environments

All commands target **preprod by default**. Pass `env=prod` on the command
line to aim at production. The only exception is `just backup`, which always
reads from prod.

```
just start              # start preprod
just start env=prod     # start prod

just migrate            # migrate preprod
just migrate env=prod   # migrate prod

just restore backups/opensauce_20240101.sql.gz              # restore into preprod
just restore backups/opensauce_20240101.sql.gz env=prod     # restore into prod

just backup             # always dumps prod (env= ignored)
```

Preprod listens on port **4001**. Prod listens on port **4000**.

---

## How it works

Each environment runs as a podman pod containing postgres and the app. Containers
in the same pod share a network namespace, so the app reaches postgres on
`localhost`. Postgres data lives in a named podman volume (`opensauce_dirt-prod-pgdata`,
`opensauce_dirt-preprod-pgdata`) that persists across restarts and rebuilds.

Put Caddy (or any reverse proxy) in front for TLS — the app speaks plain HTTP.

---

## First-time setup

**1. Build the prod image** (from the project root):

```
just prod-build
```

**2. Create your env files:**

```
cp .env.example .env.preprod
cp .env.example .env.prod
```

Fill in both files. The values can differ between environments (different
passwords, hostnames, etc.). Generate secrets with:

```
openssl rand -base64 48   # SECRET_KEY_BASE
openssl rand -base64 32   # TOKEN_SIGNING_SECRET and CLOAK_KEY
```

For preprod, set `DATABASE_URL` to use `opensauce_preprod`.
For prod, set `DATABASE_URL` to use `opensauce_prod`.

**3. Start preprod first and verify:**

```
just start
just migrate
```

**4. Then start prod:**

```
just start env=prod
just migrate env=prod
```

---

## Reverse proxy (Caddy example)

```
app.example.com {
    reverse_proxy localhost:4000
}

preprod.example.com {
    reverse_proxy localhost:4001
}
```

---

## Day-to-day commands

All commands default to preprod. Append `env=prod` for production.

| Command | What it does |
|---|---|
| `just start` | Start the pod (postgres + app) |
| `just stop` | Stop the pod |
| `just restart` | Stop then start |
| `just logs` | Tail app logs |
| `just migrate` | Run pending migrations |
| `just console` | Open a live IEx console inside the app |
| `just build` | Rebuild and reload the prod image |
| `just destroy` | Remove pod and containers (data volume kept) |
| `just backup` | Dump **prod** database to `prod/backups/` (always prod) |
| `just backups` | List available backups |
| `just restore <file>` | Restore a backup into preprod (3s warning before overwrite) |
| `just anonymise` | Replace all PII in the target env database with fake data |
| `just anon-from-prod` | Full pipeline: dump prod → restore to preprod → anonymise |

---

## Deploying a new version

```
just build
just stop env=prod
just destroy env=prod
just start env=prod
just migrate env=prod
```

Test the same build on preprod first:

```
just build
just restart
just migrate
```

---

## Moving prod data to dev

Operators run this. It strips all customer PII and replaces it with fake
but structurally valid data before handing off to developers.

```
just anon-from-prod
```

That single command: dumps prod, restores to preprod, anonymises in place.
Developers then pull from preprod, or the operator hands them the anonymised
dump directly.

What gets anonymised (`prod/anonymise.sql`):
- **crm_customers** — names, email, phone
- **crm_addresses** — street, city, province, postal, notes, coordinates
- **accounts_users** — names, email (emails are made unique via row number)
- **accounts_organisations** — phone, payment info, contact details (org name preserved)
- **accounts_tokens** — truncated entirely (all invalid after a data move)

The SQL is idempotent. Running `just anonymise` a second time on already-anonymised
data is safe.

## Uploads

By default, uploaded files go to `/var/lib/opensauce/uploads` inside the
container and are lost when the container is replaced. To persist them:

1. `podman volume create opensauce_dirt-prod-uploads`
2. Add to `_start-app` in the justfile: `-v opensauce_dirt-{{env}}-uploads:/var/lib/opensauce/uploads \`

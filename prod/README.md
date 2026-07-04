# Production

Production runs on a VPS at **dirt.opensauce.sh**. The dev machine builds the
image with nix and streams it to the VPS over ssh — no registry involved. The
VPS only needs `podman`, `just`, and `caddy`.

Code moves forward (dev → VPS). Data moves back (VPS → dev), and it is
**anonymised on the VPS before it leaves** — raw PII never lands on a dev
machine.

```
dev machine                          VPS (dirt.opensauce.sh)
───────────                          ───────────────────────
just deploy          ──── image ───▶ podman load, tag :latest
just vps <target>    ──── ssh ─────▶ ~/dirt/justfile (this dir)
just fetch-anon      ◀─── dump ───── anon-from-prod, then preprod pg_dump
just fetch-backup    ◀─── dump ───── raw prod pg_dump (off-host backup)
```

---

## Environments

Both environments live on the VPS as podman pods. All VPS-side commands target
**preprod by default**; pass `env=prod` to aim at production. The only
exceptions are `backup` and `backup-uploads`, which always read from prod.

Preprod listens on port **4001**, prod on **4000**. Containers in a pod share a
network namespace, so the app reaches postgres on `localhost` and postgres is
never exposed outside the pod.

**Caddy** terminates TLS for both hostnames. It runs as a standalone container
on the host network (reaching both pods on `localhost:4000/4001`), not inside
either pod — deliberately. Pods are lifecycle and blast-radius boundaries:
`destroy` on one env must never touch the other, app containers are replaced
every deploy while caddy holds long-lived TLS state, and a single shared
network namespace would make the two apps and two postgreses fight over ports.
Its config is `prod/Caddyfile` in the repo, synced to `~/dirt/caddy/` by
`just deploy` and applied with `just vps caddy-reload`.

Data lives in named volumes that survive restarts, rebuilds, and `destroy`:

| Volume | Contents |
|---|---|
| `opensauce_dirt-{prod,preprod}-pgdata` | PostgreSQL data |
| `opensauce_dirt-{prod,preprod}-uploads` | Uploaded files (photos, signatures) |
| `opensauce_dirt-caddy-data` | TLS certificates (Let's Encrypt) |

---

## VPS provisioning (one-time)

1. **DNS** — point `dirt.opensauce.sh` (and `preprod.dirt.opensauce.sh` if you
   want preprod reachable) at the VPS.

2. **Packages** — `podman`, `just`, `rsync`. (Caddy and postgres arrive as
   digest-pinned images via `just deploy-caddy` / `just deploy-db`.)

3. **Deploy user** — run everything rootless as a normal user. Two things make
   rootless survive reboots:

   ```
   loginctl enable-linger $USER
   systemctl --user enable --now podman-restart.service
   ```

   Linger lets user services run without a login session; `podman-restart`
   restarts containers with `--restart always` (which the start targets set)
   after a reboot.

4. **Unprivileged ports** — rootless caddy binds 80/443 (TCP + UDP for
   HTTP/3), which needs one sysctl:

   ```
   echo 'net.ipv4.ip_unprivileged_port_start=80' \
     | sudo tee /etc/sysctl.d/50-unprivileged-ports.conf
   sudo sysctl --system
   ```

5. **Env files** — in `~/dirt/` (created by the first `just deploy`):

   ```
   cp .env.example .env.preprod
   cp .env.example .env.prod
   ```

   Fill in both. Generate secrets with:

   ```
   openssl rand -base64 48   # SECRET_KEY_BASE
   openssl rand -base64 32   # TOKEN_SIGNING_SECRET and CLOAK_KEY
   ```

   Use different secrets per environment, with one caveat: if Cloak-encrypted
   columns ever land in the schema, a prod dump can only be decrypted with
   prod's `CLOAK_KEY` — at that point preprod must share prod's key or the
   restored columns are garbage. No column is encrypted today.

   Set `HOST=dirt.opensauce.sh` in `.env.prod` (and the preprod hostname in
   `.env.preprod`), and the matching `DATABASE_URL` database name
   (`opensauce_prod` / `opensauce_preprod`).

6. **First start** — from the dev machine:

   ```
   just deploy
   just deploy-db                # digest-pinned postgres image
   just deploy-caddy             # digest-pinned caddy image
   just vps caddy-start          # TLS edge up (certs issue on first request)
   just vps start                # preprod up, migrations run on boot
   just vps start env=prod
   ```

---

## Deploying a new version

The image version comes from the `VERSION` file at the repo root — bump it
when you cut a release. `just deploy` builds, streams the image to the VPS,
and tags it both `:<version>` and `:latest`.

Migrations run automatically when the app container boots, so a rollout is:

```
just deploy
just vps restart                # test on preprod first
just vps restart env=prod
```

`restart` reuses the existing container (and its image) if one exists — after
shipping a new image, recreate the app container instead:

```
just vps destroy && just vps start
just vps destroy env=prod && just vps start env=prod
```

Volumes are preserved by `destroy`; only the containers are replaced.

**Rollback** — every shipped version stays tagged on the VPS:

```
just vps destroy env=prod
just vps start env=prod image_tag=0.4.0
```

(Only helps if the bad version didn't run destructive migrations — check
before rolling back across a migration boundary.)

**Postgres and caddy** are the stock upstream images, pinned by digest in
`containers/base-image-postgres-18.nix` / `containers/base-image-caddy-2.nix`
and loaded on hosts as `opensauce_dirt-postgres:18` / `opensauce_dirt-caddy:2`
— never pulled from a registry, so they can't drift. To move a pin:
`just update-postgres && just deploy-db` (then `just vps destroy && just vps
start` per environment) or `just update-caddy && just deploy-caddy` (then
recreate the caddy container: `podman rm -f opensauce_dirt-caddy` on the VPS
and `just vps caddy-start` — certs live in the data volume and survive).
Postgres pgdata volumes are version-scoped, so a *major* postgres bump needs
a dump/restore, not just a container swap.

---

## Day-to-day commands

Run from the dev machine via `just vps <target>`, or directly on the VPS in
`~/dirt/`. Everything defaults to preprod; append `env=prod` for production.

| Command | What it does |
|---|---|
| `just vps start` | Start the pod (postgres + app; migrations run on boot) |
| `just vps stop` | Stop the pod |
| `just vps restart` | Stop then start |
| `just vps destroy` | Remove pod + containers (volumes kept) |
| `just vps logs` | Tail app logs |
| `just vps migrate` | Run migrations manually against a live container |
| `just vps console` | Open a live IEx console inside the app |
| `just vps backup` | Dump **prod** DB to `~/dirt/backups/` on the VPS |
| `just vps backup-uploads` | Dump **prod** uploads volume likewise |
| `just vps backups` | List on-VPS backups |
| `just vps restore <file>` | Restore a dump into preprod (3s warning) |
| `just vps anonymise` | Replace all PII in the target env DB |
| `just vps anon-from-prod` | Dump prod → restore to preprod → anonymise |
| `just vps caddy-start` | Start the TLS edge (serves both envs) |
| `just vps caddy-reload` | Apply Caddyfile changes without dropping connections |
| `just vps caddy-logs` | Tail caddy logs |

---

## Backups

On-VPS backups (`just vps backup`) protect against operator error, not disk
loss — they live on the same disk as the database. Pull them off-host from the
dev machine:

```
just fetch-backup     # raw prod DB dump → prod/backups/ locally
just fetch-uploads    # prod uploads volume → prod/backups/ locally
```

Cron `just fetch-backup` (or rclone the VPS `backups/` dir to object storage)
so at least one copy always lives off the box. `prod/backups/` is gitignored.

Dumps are `pg_dump --clean --if-exists`, so restoring over an existing
database is safe and idempotent; restores run with `ON_ERROR_STOP` so a failed
restore fails loudly instead of half-applying.

---

## Moving prod data to dev

One command from the dev machine:

```
just fetch-anon
```

That runs `anon-from-prod` on the VPS (dump prod → restore into preprod →
anonymise in place), then pulls a dump of the **anonymised preprod** database
down to `prod/backups/opensauce_anon_*.sql.gz`. Load it into the local dev DB
with:

```
just load-anon prod/backups/opensauce_anon_<timestamp>.sql.gz
```

What gets anonymised (`prod/anonymise.sql`, idempotent):

- **crm_customers** — names, email, phone
- **crm_addresses** — street, city, province, postal, notes, coordinates
- **accounts_users** — names, email (emails made unique via row number)
- **accounts_organisations** — phone, payment info, contact details (org name preserved)
- **accounts_tokens** — truncated (all invalid after a data move)
- **accounts_api_keys** — truncated (hashes remain valid credentials)

Not covered: uploaded files (photos, signatures) are PII but live in the
uploads volume, not the database — they simply don't travel with the dump.
User password hashes do travel; they're bcrypt hashes of real passwords, so
treat even anonymised dumps as sensitive.

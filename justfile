set shell := ["bash", "-eo", "pipefail", "-c"]

# ─────────────────────────────────────────
# Config
# ─────────────────────────────────────────
project_name := "opensauce_dirt"
postgres_dir := ".postgres"
nix_image    := "ghcr.io/nixos/nix"
podman       := "podman"
workspace    := "/workspace"
project_root := justfile_directory()
nix_flags    := "--extra-experimental-features nix-command --extra-experimental-features flakes"
nix_envs     := "NIX_USER_CONF_FILES=/workspace/.nix-config"
version      := `cat VERSION`
vps_host     := env_var_or_default("DIRT_VPS", "dirt.opensauce.sh")
vps_dir      := "dirt"
dev_email    := env_var_or_default("DEV_EMAIL", "")

_default:
    @just --list

_has-nix       := `command -v nix || true`
_has-nix-store := `podman volume inspect nix-store &>/dev/null && echo "yes" || echo ""`
_in-container  := `[ -f /run/.containerenv ] && echo "yes" || echo ""`

[no-exit-message]
_not-in-container:
    @[ ! -f /run/.containerenv ] || { echo "leave container to run this"; exit 1; }

_need-nix-store:
    @[ -n "{{_has-nix-store}}" ] || exit 1

# ─────────────────────────────────────────
# App — Elixir / Phoenix
# ─────────────────────────────────────────

# Start dev services (PostgreSQL 18)
up:
    mkdir -p {{postgres_dir}}
    {{podman}} run -d \
        --name opensauce-postgres \
        --replace \
        -p 5432:5432 \
        -e POSTGRES_DB=opensauce_dev \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD=postgres \
        -e PGDATA=/var/lib/postgresql/data/pgdata \
        -v "$(pwd)/{{postgres_dir}}:/var/lib/postgresql/data:Z" \
        postgres:18

# Set up the app and start the dev server (run `just up` first)
dev:
    mix setup
    mix phx.server

server:
    mix phx.server

# Stop dev services and wipe all local data
down:
    {{podman}} stop opensauce-postgres 2>/dev/null || true
    {{podman}} rm   opensauce-postgres 2>/dev/null || true
    {{podman}} unshare rm -rf {{postgres_dir}}
    mkdir -p {{postgres_dir}}

nuke:
    rm -rf priv/repo/migrations/* priv/resource_snapshots/*
    mix ash.reset
    mix ash.codegen initial_schema
    mix ash.migrate
    mix ecto.migrate --migrations-path priv/repo/manual_migrations
    just nuke-test

# Reset the test DB to match current migrations (run after `just nuke` or when test DB drifts)
nuke-test:
    MIX_ENV=test mix ash.reset
    MIX_ENV=test mix ash.migrate
    MIX_ENV=test mix ecto.migrate --migrations-path priv/repo/manual_migrations

unnuke:
    rm -rf priv/repo/migrations priv/resource_snapshots
    git restore priv/repo/migrations priv/resource_snapshots
    mix ash.reset
    mix ash.migrate
    mix ecto.migrate --migrations-path priv/repo/manual_migrations

# ─────────────────────────────────────────
# Nix / Container (krump)
# ─────────────────────────────────────────

# Bootstrap the nix-store volume, git hooks, and generate devcontainer.json
bootstrap: devcontainer-json
    #!/usr/bin/env bash
    if [ -z "{{_has-nix-store}}" ]; then
        echo "Bootstrapping nix-store volume..."
        {{podman}} run --rm \
          -v nix-store:/nix \
          {{nix_image}} \
          cp -a /nix/. /nix/
        echo "nix-store volume ready."
    fi
    git config core.hooksPath .githooks
    echo "Git hooks installed."

devcontainer-json:
    echo '{"name":"{{project_name}}","image":"localhost/{{project_name}}-dev:latest","remoteUser":"root","mounts":[{"source":"nix-store","target":"/nix","type":"volume"}],"runArgs":["--userns=keep-id:uid=0,gid=0"]}' > .devcontainer/devcontainer.json

# Load an image onto the host podman
_load-image target: _not-in-container _need-nix-store
    {{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}} \
      nix {{nix_flags}} run .#{{target}} | {{podman}} load -q

# Run an image interactively
_run-image image: _not-in-container _need-nix-store
    {{podman}} run --rm -it \
      --network host \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -e SHELL \
      -w {{workspace}} \
      {{image}}

_nix +args:
    #!/usr/bin/env bash
    set -eo pipefail
    if [ -n "$(command -v nix || true)" ]; then
        nix {{args}}
    else
        just _need-nix-store
        podman run --rm \
          -v {{project_root}}:{{workspace}}:z \
          -v nix-store:/nix \
          -e NIX_USER_CONF_FILES={{workspace}}/.nix-config \
          -w {{workspace}} \
          {{nix_image}} \
          nix {{args}}
    fi

_build +cmd:
    #!/usr/bin/env bash
    set -eo pipefail
    if [ -n "{{_in-container}}" ]; then
        eval {{cmd}}
    else
        {{podman}} run --rm \
          -v {{project_root}}:{{workspace}}:z \
          -v nix-store:/nix \
          --userns keep-id:uid=0,gid=0 \
          -w {{workspace}} \
          localhost/{{project_name}}-dev:latest \
          sh -c "{{cmd}}"
    fi

# Run bare NixOS within a container, mount workspace
naked-nix: _not-in-container _need-nix-store
    {{podman}} run -it --rm \
      -e="{{nix_envs}}" \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}}

# Load and start dev container shell
nix-dev: _not-in-container bootstrap
    just _load-image dev-image
    just _run-image localhost/{{project_name}}-dev:latest

# Load devcontainer image into podman
devcontainer: _not-in-container
    just _load-image dev-image

# Load staticserver image into podman
staticserver: _not-in-container
    just _load-image staticserver-image

# Generate docs/package-lock.json using nix-provided npm (commit the result)
docs-lock:
    just _build "cd /workspace/docs && npm install --package-lock-only"

# Update the mix deps hash in containers/prod/default.nix (run when mix.lock changes)
prod-deps-hash: _not-in-container _need-nix-store
    #!/usr/bin/env bash
    set -euo pipefail
    output=$({{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}} \
      nix {{nix_flags}} --show-trace run .#prod-image 2>&1 || true)
    hash=$(echo "$output" | grep 'got:' | grep -oP 'sha256-[A-Za-z0-9+/=]+' || true)
    if [ -z "$hash" ]; then
      echo "Could not extract hash — nix output:"
      echo "$output"
      exit 1
    fi
    sed -i "s|hash = pkgs.lib.fakeHash;|hash = \"${hash}\";|" containers/prod/default.nix
    sed -i -E "s|hash = \"sha256-[A-Za-z0-9+/=]+\";|hash = \"${hash}\";|" containers/prod/default.nix
    echo "Updated containers/prod/default.nix with sha256 = \"${hash}\""

# Build and load the prod image
prod-build: _not-in-container
    just _load-image prod-image

# ─────────────────────────────────────────
# Deploy (VPS at dirt.opensauce.sh — override with DIRT_VPS env var)
# ─────────────────────────────────────────

# Build the prod image, stream it to the VPS, tag it :latest, sync prod/ tooling
deploy: _not-in-container _need-nix-store
    {{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}} \
      nix {{nix_flags}} run .#prod-image | ssh -C {{vps_host}} podman load
    ssh {{vps_host}} podman tag {{project_name}}-prod:{{version}} {{project_name}}-prod:latest
    ssh {{vps_host}} mkdir -p {{vps_dir}}/caddy
    rsync -a prod/justfile prod/anonymise.sql prod/.env.example {{vps_host}}:{{vps_dir}}/
    rsync -a prod/Caddyfile {{vps_host}}:{{vps_dir}}/caddy/
    @echo "Shipped {{project_name}}-prod:{{version}} to {{vps_host}}."
    @echo "Roll out with: just vps destroy && just vps start   (then just vps env=prod ...)"

# Ship the digest-pinned postgres image to the VPS (first setup + after `just update-postgres`)
deploy-db: _not-in-container _need-nix-store
    {{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}} \
      nix {{nix_flags}} run .#postgres-image | ssh -C {{vps_host}} podman load
    ssh {{vps_host}} podman tag postgres:18 {{project_name}}-postgres:18

# Ship the digest-pinned caddy image to the VPS (first setup + after `just update-caddy`)
deploy-caddy: _not-in-container _need-nix-store
    {{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}} \
      nix {{nix_flags}} run .#caddy-image | ssh -C {{vps_host}} podman load
    ssh {{vps_host}} podman tag caddy:2 {{project_name}}-caddy:2

# Run a prod/justfile target on the VPS, e.g. `just vps env=prod start`
# (env=prod and other overrides go BEFORE the recipe name)
vps +args:
    ssh -t {{vps_host}} "cd {{vps_dir}} && just {{args}}"

# Pull a raw prod DB dump down from the VPS (off-host backup — cron this)
fetch-backup:
    mkdir -p prod/backups
    ssh {{vps_host}} "podman exec {{project_name}}-prod-db pg_dump --clean --if-exists -U postgres opensauce_prod | gzip" \
      > prod/backups/opensauce_prod_$(date +%Y%m%d_%H%M%S).sql.gz
    @ls -lh prod/backups/ | tail -1

# Pull a prod uploads volume dump down from the VPS
fetch-uploads:
    mkdir -p prod/backups
    ssh {{vps_host}} "podman volume export {{project_name}}-prod-uploads | gzip" \
      > prod/backups/uploads_$(date +%Y%m%d_%H%M%S).tar.gz
    @ls -lh prod/backups/ | tail -1

# Raw PII never leaves the box:
# refresh preprod from prod, anonymise on the VPS, pull the clean dump down.
# Anonymised emails route to dev_email (or $DEV_EMAIL) so magic links reach you:
#   just dev_email=you@example.com fetch-anon
fetch-anon:
    @[ -n "{{dev_email}}" ] || { echo "Set DEV_EMAIL or run: just dev_email=you@example.com fetch-anon"; exit 1; }
    mkdir -p prod/backups
    just vps "dev_email={{dev_email}}" anon-from-prod
    ssh {{vps_host}} "podman exec {{project_name}}-preprod-db pg_dump --clean --if-exists -U postgres opensauce_preprod | gzip" \
      > prod/backups/opensauce_anon_$(date +%Y%m%d_%H%M%S).sql.gz
    @ls -lh prod/backups/ | tail -1

# Load an anonymised dump into the local dev database
#   just load-anon prod/backups/opensauce_anon_20260703_120000.sql.gz
load-anon file:
    gunzip -c {{file}} | {{podman}} exec -i opensauce-postgres psql -q -v ON_ERROR_STOP=1 -U postgres opensauce_dirt_dev
    @echo "Dev DB now holds anonymised prod data."

# Build and load the docs image (run `just docs-lock` first if no package-lock.json)
docs: _not-in-container
    just _load-image docs-image

# Run the docs server on port 8080 (detached)
run-docs:
    {{podman}} run -d --rm \
      --name {{project_name}}-docs \
      -p 8080:8080 \
      {{project_name}}-docs:latest

# Stop the docs server
stop-docs:
    {{podman}} stop {{project_name}}-docs

# Load busykrump image into podman
busykrump: _not-in-container
    just _load-image busykrump-image

# Run prebuilt dev container interactively
run-dev:
    just _run-image localhost/{{project_name}}-dev:latest

# Run staticserver (serves ./assets on port 8080)
run-staticserver: staticserver
    {{podman}} run -it --rm \
      -v {{project_root}}/assets:/assets:z \
      -p 8080:8080 \
      staticserver:latest

# Update the nix base image used for containers
update-base-image image tag: _need-nix-store
    #!/usr/bin/env bash
    output="containers/base-image-$(echo {{image}} | tr '/' '-')-{{tag}}.nix"
    {{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      -e NIX_USER_CONF_FILES={{workspace}}/.nix-config \
      -w {{workspace}} \
      {{nix_image}} \
      nix run nixpkgs#nix-prefetch-docker -- --image-name {{image}} --image-tag {{tag}} \
      | sed -n '/^{/,$ p' \
      > $output

# Regenerate the busybox base image nix expression
update-busybox:
    just update-base-image busybox latest

# Re-pin the postgres image to the current postgres:18 digest
update-postgres:
    just update-base-image postgres 18

# Re-pin the caddy image to the current caddy:2 digest
update-caddy:
    just update-base-image caddy 2

# Show flake outputs
flake-show:
    just _nix {{nix_flags}} flake show

# Update flake.lock
update:
    just _nix {{nix_flags}} flake update

# Garbage collect old nix builds
gc:
    just _nix {{nix_flags}} store gc

# Format nix files
fmt:
    just _nix {{nix_flags}} run nixpkgs#nixfmt -- **/*.nix

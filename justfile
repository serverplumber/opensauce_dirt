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

# Start dev services (PostgreSQL 16)
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
        postgres:16

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

# Bootstrap the nix-store volume and generate devcontainer.json
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

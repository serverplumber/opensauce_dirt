set shell := ["bash", "-euo", "pipefail", "-c"]

postgres_dir := ".postgres"

# Start dev services (PostgreSQL 16)
up:
    mkdir -p {{postgres_dir}}
    podman run -d \
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
    podman stop opensauce-postgres 2>/dev/null || true
    podman rm   opensauce-postgres 2>/dev/null || true
    podman unshare rm -rf {{postgres_dir}}
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

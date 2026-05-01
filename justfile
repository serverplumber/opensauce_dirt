set shell := ["bash", "-cu"]

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

# Stop dev services and wipe all local data
down:
    podman stop opensauce-postgres 2>/dev/null || true
    podman rm   opensauce-postgres 2>/dev/null || true
    rm -rf {{postgres_dir}}

set shell := ["bash", "-cu"]

postgres_dir := ".postgres"
minio_dir    := ".minio"

# Start dev services (PostgreSQL 16 + MinIO)
up:
    mkdir -p {{postgres_dir}} {{minio_dir}}
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
    podman run -d \
        --name opensauce-minio \
        --replace \
        -p 9000:9000 \
        -p 9001:9001 \
        -e MINIO_ROOT_USER=minioadmin \
        -e MINIO_ROOT_PASSWORD=minioadmin \
        -v "$(pwd)/{{minio_dir}}:/data:Z" \
        --entrypoint sh \
        minio/minio \
        -c 'mkdir -p /data/opensauce && minio server /data --console-address ":9001"'

# Set up the app and start the dev server (run `just up` first)
dev:
    mix setup
    mix phx.server

# Stop dev services and wipe all local data
down:
    podman stop opensauce-postgres opensauce-minio 2>/dev/null || true
    podman rm   opensauce-postgres opensauce-minio 2>/dev/null || true
    rm -rf {{postgres_dir}} {{minio_dir}}

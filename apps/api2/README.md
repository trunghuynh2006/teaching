# API2 (Go + PostgreSQL)

## Run locally

1. Start PostgreSQL:

```bash
docker compose up -d
```

2. Set env vars:

```bash
cp .env.example .env
```

3. Run API server:

```bash
go run .
```

Generate sqlc query code:

```bash
go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml
```

API base URL: http://localhost:8000

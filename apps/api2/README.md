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

API base URL: http://localhost:8000

# AI Service (Go)

Basic AI content generation service for lesson/skill drafts.

## Run locally

1. Start PostgreSQL (reuse api2 compose):

```bash
cd ../api2
docker compose up -d
cd ../ai
```

2. Set env vars:

```bash
cp .env.example .env
```

3. Start server:

```bash
go run .
```

API base URL: http://localhost:8100

Prompt caching:
- Backed by PostgreSQL table `prompt_cache_entries`
- `AI_PROMPT_CACHE_TTL_SECONDS` (default `900`)
- `AI_PROMPT_CACHE_MAX_ENTRIES` (default `512`, set `0` to disable)

## Endpoint

- `POST /content/generate`

Example request body:

```json
{
  "topic": "Fractions",
  "audience": "Grade 6 students",
  "difficulty": "beginner",
  "language": "English"
}
```

Generate sqlc query code:

```bash
go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml
```

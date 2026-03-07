# AI Service (Go)

Basic AI content generation service for lesson/skill drafts.

## Run locally

1. Set env vars:

```bash
cp .env.example .env
```

2. Start server:

```bash
go run .
```

API base URL: http://localhost:8100

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

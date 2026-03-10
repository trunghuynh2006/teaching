# Architecture

## Service map

```
Browser
  │
  ▼
┌─────────────────────┐
│  web  (React SPA)   │  :5173
│  TypeScript         │
└──────────┬──────────┘
           │ HTTP
           ▼
┌─────────────────────┐
│  api2  (main API)   │  :8000
│  Go                 │
└──────┬──────────────┘
       │              │
       │ HTTP         │ HTTP
       ▼              ▼
┌────────────┐  ┌─────────────────────┐
│  ai        │  │ lesson-plan-        │
│  Go  :8100 │  │ generator           │
└────────────┘  │ Python  :8200       │
       │        └─────────────────────┘
       │ HTTP            │ HTTP
       ▼                 ▼
  OpenAI API         OpenAI API
```

## Allowed call directions

| Caller                  | May call                        | May NOT call              |
|-------------------------|---------------------------------|---------------------------|
| `web`                   | `api2`                          | `ai`, `lesson-plan-generator` |
| `api2`                  | `ai`, `lesson-plan-generator`   | `web`                     |
| `ai`                    | _(external APIs only)_          | all internal services     |
| `lesson-plan-generator` | _(external APIs only)_          | all internal services     |

Rules are declared in [`deps.yaml`](deps.yaml) and enforced by
[`scripts/check_deps.py`](scripts/check_deps.py).

## Port assignments

| Service                 | Port |
|-------------------------|------|
| web                     | 5173 |
| api2                    | 8000 |
| ai                      | 8100 |
| lesson-plan-generator   | 8200 |

## Communication pattern

All inter-service communication is synchronous HTTP. Service URLs are injected
via environment variables — never hardcoded.  Each app's `.env.example` shows
the variables it expects.

## Known violations (to be fixed)

- `web/src/config.ts` references `AI_URL` (port 8100) directly.
  Fix: remove `VITE_AI_URL` from web; route all AI calls through `api2`.

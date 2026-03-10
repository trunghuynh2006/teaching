# Teaching Platform — Claude Context

## Project overview

Monorepo for a teaching / study platform. Apps live under `apps/`.
Build system: Turborepo + pnpm workspaces. Package manager: pnpm.

## Apps

| App                   | Language   | Port | Role |
|-----------------------|------------|------|------|
| `web`                 | TypeScript | 5173 | React SPA (student + teacher UI) |
| `api2`                | Go         | 8000 | Main backend API |
| `ai`                  | Go         | 8100 | AI content generation (OpenAI proxy) |
| `lesson-plan-generator` | Go       | 8200 | Generates video plan JSON from lessons |

## Service dependency rules

Defined authoritatively in `deps.yaml`. Enforced by `scripts/check_deps.py`.

```
web  ──►  api2  ──►  ai
                └──►  lesson-plan-generator
```

**Rules (must_not_call is the inverse):**
- `web` may only call `api2`
- `api2` may call `ai` and `lesson-plan-generator`
- `ai` calls no internal services
- `lesson-plan-generator` calls no internal services

All internal service URLs must come from environment variables — never hardcode
a port or hostname for another internal service in application source code.

## Enforcing the rules

Run the lint check before committing:

```bash
python3 scripts/check_deps.py
```

It is also wired into `pnpm lint` via turbo.

## Shared packages

Reusable Go libraries live under `packages/`. They are **not** standalone services.

| Package        | Module path      | Purpose |
|----------------|------------------|---------|
| `packages/llm` | `t2t.dev/llm`    | Provider-agnostic LLM chat completion interface + OpenAI implementation |

All Go modules (apps + packages) are linked via `go.work` at the repo root.
This means local changes to `packages/llm` are immediately available to all apps
without publishing to a registry.

To use `t2t.dev/llm` in a new Go app:
1. Add `require t2t.dev/llm@v0.0.0` via `go mod edit -require t2t.dev/llm@v0.0.0`
2. Run `go mod tidy` — go.work resolves it to the local `packages/llm` source.

## Key conventions

- Shared Go models live in `scripts/generate_shared_models.go` and are generated
  into each Go app's `internal/sharedmodels/` package via `pnpm generate:models`.
- Each app manages its own `.env` (gitignored). Commit only `.env.example`.
- Go apps use `internal/` to prevent cross-app imports at the source level.
- All backend apps are Go; the frontend is TypeScript (React).

# Study Platform Monorepo

Monorepo with:
- `apps/web`: React + Vite frontend with animated UI and sidebar navigation
- `apps/api`: FastAPI backend with PostgreSQL + JWT auth
- Tooling: `pnpm` workspaces + `turborepo` for repo management

## Features

- JWT-based authentication (`/auth/login`)
- Four roles: `learner`, `teacher`, `admin`, `parent`
- Different landing/dashboard view and menu per role in frontend
- Hardcoded demo users seeded into PostgreSQL on backend startup
- Responsive layout with modern CSS animations and a sidebar menu

## Demo users

- `learner_alex` / `Pass1234!`
- `learner_mia` / `Pass1234!`
- `teacher_john` / `Teach1234!`
- `teacher_nina` / `Teach1234!`
- `admin_sara` / `Admin1234!`
- `admin_mike` / `Admin1234!`
- `parent_olivia` / `Parent1234!`
- `parent_david` / `Parent1234!`

## Prerequisites

- Node.js 20+
- pnpm 9+
- Python 3.11+
- Docker (for local PostgreSQL)

## Run backend

```bash
cd apps/api
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
docker compose up -d
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend URLs:
- API: http://localhost:8000
- Swagger: http://localhost:8000/docs

## Run frontend

```bash
cd apps/web
cp .env.example .env
pnpm install
pnpm dev
```

Frontend URL:
- App: http://localhost:5173

## Run as monorepo (optional)

Install JS deps once at repo root:

```bash
pnpm install
```

Then start frontend + backend together from root:

```bash
pnpm dev
```

Note: root `pnpm dev` expects Python dependencies to already be installed in your active environment.

## Makefile shortcuts

From repo root:

```bash
make start-frontend
make start-backend
make migration-up
make migration-new m="add profile fields"
```

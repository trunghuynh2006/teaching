# API (FastAPI + PostgreSQL)

## Run locally

1. Create and activate a virtual environment.
2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Start PostgreSQL:

```bash
docker compose up -d
```

4. Set env vars:

```bash
cp .env.example .env
```

5. Run API server:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs: http://localhost:8000/docs

## Migrations (Alembic)

This project keeps dev auto-create behavior (`Base.metadata.create_all`) on startup,
and also supports explicit migrations.

Run all migrations:

```bash
alembic upgrade head
```

Create a new migration after model changes:

```bash
alembic revision --autogenerate -m "describe change"
```

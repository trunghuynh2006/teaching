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

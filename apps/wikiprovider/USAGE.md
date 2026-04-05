# wikiprovider

A lightweight proxy service between the teaching platform and the Wikidata SPARQL endpoint.
Adds file-based caching and rate limiting so the rest of the platform never hits Wikidata directly.

## Architecture

```
api2  →  wikiprovider  →  (file cache | Wikidata SPARQL)
```

- **Port**: 8200 (default)
- **Auth**: none — internal service only, not exposed to the web
- **Cache**: JSON files on disk, keyed by query hash
- **Rate limits**: 20 req/s inbound · 2 req/s outbound to Wikidata

---

## Configuration

All settings are environment variables (`.env` file supported).

| Variable           | Default                                              | Description                        |
|--------------------|------------------------------------------------------|------------------------------------|
| `PORT`             | `8200`                                               | Listening port                     |
| `CACHE_DIR`        | `/home/trung/Documents/.teachingdata/wikiprovider`   | Directory for cached query files   |
| `CACHE_TTL_HOURS`  | `24`                                                 | Cache TTL in hours                 |

---

## Running

```bash
# via Makefile (recommended)
make start-wiki

# directly
cd apps/wikiprovider && go run .

# with custom config
PORT=8200 CACHE_DIR=/tmp/wiki-cache go run .
```

---

## Endpoints

### `GET /health`
Returns `{"status": "ok"}`. Use for liveness checks.

---

### `GET /concepts/search?q=<query>&limit=<n>`
Search Wikidata for concepts whose label contains the query string.

| Param   | Required | Default | Description              |
|---------|----------|---------|--------------------------|
| `q`     | yes      | —       | Label search term        |
| `limit` | no       | `20`    | Max results to return    |

```bash
curl "http://localhost:8200/concepts/search?q=newton"
```

---

### `GET /concepts/by-domain?domain=<domain>&limit=<n>`
Returns concepts that are subclasses of the named domain in the Wikidata graph (`P279*`).

| Param    | Required | Default | Description              |
|----------|----------|---------|--------------------------|
| `domain` | yes      | —       | Domain label in English  |
| `limit`  | no       | `50`    | Max results to return    |

```bash
curl "http://localhost:8200/concepts/by-domain?domain=physics"
curl "http://localhost:8200/concepts/by-domain?domain=computer+science&limit=100"
```

---

### `GET /concepts/{qid}`
Returns a single Wikidata item by QID, including its direct parent concepts (`P279`).

```bash
curl "http://localhost:8200/concepts/Q11639"   # Newton's laws of motion
```

---

## Response format

All endpoints return a JSON array of concept objects:

```json
[
  {
    "qid": "Q11639",
    "label": "Newton's laws of motion",
    "description": "three physical laws that form the basis of classical mechanics",
    "parent_qid": "Q45585",
    "parent_label": "classical mechanics"
  }
]
```

---

## Pre-caching domains

Run these before starting the app to populate the cache without hitting Wikidata at runtime.

```bash
# Single domain
make cache-wiki-domain DOMAIN=physics
make cache-wiki-domain DOMAIN="computer science"

# All default domains (physics, mathematics, chemistry, biology,
# computer science, history, economics)
make cache-wiki-domains

# Custom list
make cache-wiki-domains WIKI_DOMAINS="physics mathematics"
```

Cache files are stored in `CACHE_DIR` as `<sha256-of-query>.json`.
They expire after `CACHE_TTL_HOURS` hours and are re-fetched on next request.

---

## Switching to a local Wikidata dump

The `runSPARQL` function in `internal/handler/handler.go` is the single point to replace.
When a local dump is ready:

1. Import the filtered dump into SQLite (see repo-level notes on Wikidata dumps)
2. Open the SQLite file in `handler.New()`
3. Replace the HTTP SPARQL call in `runSPARQL` with a SQLite query
4. Remove the outbound rate limiter — it's no longer needed

The cache layer, HTTP handlers, and api2 client require no changes.

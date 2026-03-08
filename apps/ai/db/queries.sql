-- name: InitGeneratedContentsTable :exec
CREATE TABLE IF NOT EXISTS generated_contents (
    id BIGSERIAL PRIMARY KEY,
    topic TEXT NOT NULL,
    audience TEXT NOT NULL,
    difficulty TEXT NOT NULL,
    language TEXT NOT NULL,
    lesson JSONB NOT NULL,
    skill JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- name: InitGeneratedContentsTopicIndex :exec
CREATE INDEX IF NOT EXISTS idx_generated_contents_topic ON generated_contents (topic);

-- name: InitGeneratedContentsCreatedAtIndex :exec
CREATE INDEX IF NOT EXISTS idx_generated_contents_created_at ON generated_contents (created_at DESC);

-- name: CreateGeneratedContent :one
INSERT INTO generated_contents (topic, audience, difficulty, language, lesson, skill)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, topic, audience, difficulty, language, lesson, skill, created_at;

-- name: GetGeneratedContentByID :one
SELECT id, topic, audience, difficulty, language, lesson, skill, created_at
FROM generated_contents
WHERE id = $1
LIMIT 1;

-- name: ListGeneratedContents :many
SELECT id, topic, audience, difficulty, language, lesson, skill, created_at
FROM generated_contents
ORDER BY created_at DESC
LIMIT $1;

-- name: InitPromptCacheEntriesTable :exec
CREATE TABLE IF NOT EXISTS prompt_cache_entries (
    cache_key TEXT PRIMARY KEY,
    response JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

-- name: InitPromptCacheEntriesExpiresAtIndex :exec
CREATE INDEX IF NOT EXISTS idx_prompt_cache_entries_expires_at ON prompt_cache_entries (expires_at);

-- name: GetPromptCacheEntry :one
SELECT cache_key, response, created_at, expires_at
FROM prompt_cache_entries
WHERE cache_key = $1
  AND expires_at > NOW()
LIMIT 1;

-- name: UpsertPromptCacheEntry :exec
INSERT INTO prompt_cache_entries (cache_key, response, expires_at)
VALUES ($1, $2, NOW() + (sqlc.arg(ttl_seconds)::int * INTERVAL '1 second'))
ON CONFLICT (cache_key) DO UPDATE
SET response = EXCLUDED.response,
    created_at = NOW(),
    expires_at = EXCLUDED.expires_at;

-- name: DeleteExpiredPromptCacheEntries :exec
DELETE FROM prompt_cache_entries
WHERE expires_at <= NOW();

-- name: PrunePromptCacheEntries :exec
DELETE FROM prompt_cache_entries
WHERE cache_key IN (
    SELECT cache_key
    FROM prompt_cache_entries
    ORDER BY created_at DESC
    OFFSET $1
);

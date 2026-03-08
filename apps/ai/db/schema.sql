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

CREATE INDEX IF NOT EXISTS idx_generated_contents_topic ON generated_contents (topic);
CREATE INDEX IF NOT EXISTS idx_generated_contents_created_at ON generated_contents (created_at DESC);

CREATE TABLE IF NOT EXISTS prompt_cache_entries (
    cache_key TEXT PRIMARY KEY,
    response JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_prompt_cache_entries_expires_at ON prompt_cache_entries (expires_at);

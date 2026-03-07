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

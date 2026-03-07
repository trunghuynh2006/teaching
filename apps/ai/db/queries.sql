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

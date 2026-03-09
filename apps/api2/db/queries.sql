-- name: InitUsersTable :exec
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(64) UNIQUE NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    role VARCHAR(20) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL
);

-- name: InitUsersUsernameIndex :exec
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);

-- name: InitUsersRoleIndex :exec
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

-- name: InitSkillsTable :exec
CREATE TABLE IF NOT EXISTS skills (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    difficulty VARCHAR(20) NOT NULL DEFAULT 'beginner',
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    tags TEXT[] NOT NULL DEFAULT '{}',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_skills_difficulty CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    CONSTRAINT chk_skills_status CHECK (status IN ('draft', 'published', 'archived'))
);

-- name: InitSkillsStatusState :exec
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'skills'
          AND column_name = 'is_published'
    ) THEN
        ALTER TABLE skills ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'draft';
        UPDATE skills
        SET status = CASE
            WHEN is_published THEN 'published'
            ELSE 'draft'
        END
        WHERE status IS NULL OR status = 'draft';
        ALTER TABLE skills DROP COLUMN IF EXISTS is_published;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_skills_status'
          AND conrelid = 'skills'::regclass
    ) THEN
        ALTER TABLE skills
        ADD CONSTRAINT chk_skills_status CHECK (status IN ('draft', 'published', 'archived'));
    END IF;
END $$;

-- name: InitSkillsCreatedTimeIndex :exec
CREATE INDEX IF NOT EXISTS idx_skills_created_time ON skills (created_time DESC);

-- name: GetUserByUsername :one
SELECT id, username, full_name, role, hashed_password
FROM users
WHERE username = $1
LIMIT 1;

-- name: GetUserHashByUsername :one
SELECT hashed_password
FROM users
WHERE username = $1
LIMIT 1;

-- name: CreateUser :exec
INSERT INTO users (username, full_name, role, hashed_password)
VALUES ($1, $2, $3, $4);

-- name: UpdateUserByUsername :exec
UPDATE users
SET full_name = $1, role = $2, hashed_password = $3
WHERE username = $4;

-- name: ListSkills :many
SELECT id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time
FROM skills
ORDER BY created_time DESC;

-- name: GetSkillByID :one
SELECT id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time
FROM skills
WHERE id = $1
LIMIT 1;

-- name: CreateSkill :one
INSERT INTO skills (id, title, description, difficulty, tags, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time;

-- name: UpdateSkillByID :one
UPDATE skills
SET title = $2,
    description = $3,
    difficulty = $4,
    tags = $5,
    updated_by = $6,
    updated_time = NOW()
WHERE id = $1
RETURNING id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time;

-- name: PublishSkillByID :one
UPDATE skills
SET status = 'published',
    updated_by = $2,
    updated_time = NOW()
WHERE id = $1
RETURNING id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time;

-- name: ArchiveSkillByID :one
UPDATE skills
SET status = 'archived',
    updated_by = $2,
    updated_time = NOW()
WHERE id = $1
RETURNING id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time;

-- name: MoveSkillToDraftByID :one
UPDATE skills
SET status = 'draft',
    updated_by = $2,
    updated_time = NOW()
WHERE id = $1
RETURNING id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time;

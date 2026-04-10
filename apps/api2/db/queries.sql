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

-- name: InitAudioRecordsTable :exec
CREATE TABLE IF NOT EXISTS audio_records (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL DEFAULT 0,
    transcript TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- name: InitAudioRecordsUserIndex :exec
CREATE INDEX IF NOT EXISTS idx_audio_records_user_id ON audio_records (user_id);

-- name: CreateAudioRecord :one
INSERT INTO audio_records (id, user_id, filename, file_size, transcript)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, user_id, filename, file_size, transcript, created_at;

-- name: ListAudioRecords :many
SELECT id, user_id, filename, file_size, transcript, created_at
FROM audio_records
ORDER BY created_at DESC;

-- name: ListAudioRecordsByUser :many
SELECT id, user_id, filename, file_size, transcript, created_at
FROM audio_records
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: MoveSkillToDraftByID :one
UPDATE skills
SET status = 'draft',
    updated_by = $2,
    updated_time = NOW()
WHERE id = $1
RETURNING id, title, description, difficulty, status, tags, created_by, updated_by, created_time, updated_time;

-- name: InitFoldersTable :exec
CREATE TABLE IF NOT EXISTS folders (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- name: InitFoldersCreatedTimeIndex :exec
CREATE INDEX IF NOT EXISTS idx_folders_created_time ON folders (created_time DESC);

-- name: InitSkillFoldersTable :exec
CREATE TABLE IF NOT EXISTS skill_folders (
    folder_id VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    skill_id VARCHAR(64) NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    added_by VARCHAR(64) NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (folder_id, skill_id)
);

-- name: CreateFolder :one
INSERT INTO folders (id, name, description, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, name, description, created_by, updated_by, created_time, updated_time;

-- name: ListFolders :many
SELECT id, name, description, created_by, updated_by, created_time, updated_time
FROM folders
ORDER BY created_time DESC;

-- name: GetFolderByID :one
SELECT id, name, description, created_by, updated_by, created_time, updated_time
FROM folders
WHERE id = $1
LIMIT 1;

-- name: UpdateFolderByID :one
UPDATE folders
SET name = $2,
    description = $3,
    updated_by = $4,
    updated_time = NOW()
WHERE id = $1
RETURNING id, name, description, created_by, updated_by, created_time, updated_time;

-- name: DeleteFolderByID :exec
DELETE FROM folders WHERE id = $1;

-- name: AddSkillToFolder :exec
INSERT INTO skill_folders (folder_id, skill_id, added_by)
VALUES ($1, $2, $3)
ON CONFLICT (folder_id, skill_id) DO NOTHING;

-- name: RemoveSkillFromFolder :exec
DELETE FROM skill_folders WHERE folder_id = $1 AND skill_id = $2;

-- name: ListSkillsInFolder :many
SELECT s.id, s.title, s.description, s.difficulty, s.status, s.tags,
       s.created_by, s.updated_by, s.created_time, s.updated_time
FROM skills s
JOIN skill_folders sf ON sf.skill_id = s.id
WHERE sf.folder_id = $1
ORDER BY sf.added_at ASC;


CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(64) UNIQUE NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    role VARCHAR(20) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

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

CREATE INDEX IF NOT EXISTS idx_skills_created_time ON skills (created_time DESC);

CREATE TABLE IF NOT EXISTS audio_records (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL DEFAULT 0,
    transcript TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audio_records_user_id ON audio_records (user_id);

CREATE TABLE IF NOT EXISTS anki_cards (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    front_text TEXT NOT NULL,
    back_text TEXT NOT NULL,
    bloom_level VARCHAR(20),
    tags TEXT[] NOT NULL DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    source_lesson_id VARCHAR(64),
    deck_id VARCHAR(64),
    ease_factor NUMERIC(4,2) NOT NULL DEFAULT 2.5,
    interval_days INT NOT NULL DEFAULT 0,
    repetitions INT NOT NULL DEFAULT 0,
    lapses INT NOT NULL DEFAULT 0,
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    due_at TIMESTAMPTZ,
    last_reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(64),
    updated_by VARCHAR(64)
);

CREATE INDEX IF NOT EXISTS idx_anki_cards_user_id ON anki_cards (user_id);

CREATE TABLE IF NOT EXISTS folders (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_folders_created_time ON folders (created_time DESC);

CREATE TABLE IF NOT EXISTS skill_folders (
    folder_id VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    skill_id VARCHAR(64) NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    added_by VARCHAR(64) NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (folder_id, skill_id)
);

CREATE TABLE IF NOT EXISTS knowledges (
    id VARCHAR(64) PRIMARY KEY,
    folder_id VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_knowledges_folder_id ON knowledges (folder_id);
CREATE INDEX IF NOT EXISTS idx_knowledges_created_time ON knowledges (created_time DESC);

CREATE TABLE IF NOT EXISTS spaces (
    id VARCHAR(64) PRIMARY KEY,
    folder_id VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    space_type VARCHAR(50) NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_spaces_folder_id ON spaces (folder_id);
CREATE INDEX IF NOT EXISTS idx_spaces_created_time ON spaces (created_time DESC);

CREATE TABLE IF NOT EXISTS space_items (
    id VARCHAR(64) PRIMARY KEY,
    space_id VARCHAR(64) NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    position INT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_space_items_space_id ON space_items (space_id);

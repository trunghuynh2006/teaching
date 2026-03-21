package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// Folder represents a named collection that can hold skills.
type Folder struct {
	ID          string             `json:"id"`
	FolderType  string             `json:"folder_type"`
	OwnerID     *string            `json:"owner_id"`
	ProgramID   *string            `json:"program_id"`
	IsLocked    bool               `json:"is_locked"`
	Name        string             `json:"name"`
	Description string             `json:"description"`
	Domain      *string            `json:"domain"`
	Theme       string             `json:"theme"`
	Icon        string             `json:"icon"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

type CreateFolderParams struct {
	ID          string  `json:"id"`
	FolderType  string  `json:"folder_type"`
	OwnerID     *string `json:"owner_id"`
	ProgramID   *string `json:"program_id"`
	IsLocked    bool    `json:"is_locked"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Domain      *string `json:"domain"`
	Theme       string  `json:"theme"`
	Icon        string  `json:"icon"`
	CreatedBy   string  `json:"created_by"`
	UpdatedBy   string  `json:"updated_by"`
}

type UpdateFolderByIDParams struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Domain      *string `json:"domain"`
	Theme       string  `json:"theme"`
	Icon        string  `json:"icon"`
	IsLocked    bool    `json:"is_locked"`
	UpdatedBy   string  `json:"updated_by"`
}

// FolderMember represents a user's shared access to a folder.
type FolderMember struct {
	FolderID  string             `json:"folder_id"`
	UserID    string             `json:"user_id"`
	Role      string             `json:"role"`
	AddedBy   *string            `json:"added_by"`
	AddedTime pgtype.Timestamptz `json:"added_time"`
}

type AddFolderMemberParams struct {
	FolderID string  `json:"folder_id"`
	UserID   string  `json:"user_id"`
	Role     string  `json:"role"`
	AddedBy  *string `json:"added_by"`
}

type RemoveFolderMemberParams struct {
	FolderID string `json:"folder_id"`
	UserID   string `json:"user_id"`
}

type AddSkillToFolderParams struct {
	FolderID string `json:"folder_id"`
	SkillID  string `json:"skill_id"`
	AddedBy  string `json:"added_by"`
}

type RemoveSkillFromFolderParams struct {
	FolderID string `json:"folder_id"`
	SkillID  string `json:"skill_id"`
}

const folderColumns = `id, folder_type, owner_id, program_id, is_locked, name, description, domain, theme, icon, created_by, updated_by, created_time, updated_time`

func scanFolder(row interface{ Scan(...any) error }, f *Folder) error {
	return row.Scan(&f.ID, &f.FolderType, &f.OwnerID, &f.ProgramID, &f.IsLocked,
		&f.Name, &f.Description, &f.Domain, &f.Theme, &f.Icon,
		&f.CreatedBy, &f.UpdatedBy, &f.CreatedTime, &f.UpdatedTime)
}

const createFolder = `
INSERT INTO folders (id, folder_type, owner_id, program_id, is_locked, name, description, domain, theme, icon, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
RETURNING ` + folderColumns

func (q *Queries) CreateFolder(ctx context.Context, arg CreateFolderParams) (Folder, error) {
	row := q.db.QueryRow(ctx, createFolder,
		arg.ID, arg.FolderType, arg.OwnerID, arg.ProgramID, arg.IsLocked,
		arg.Name, arg.Description, arg.Domain, arg.Theme, arg.Icon,
		arg.CreatedBy, arg.UpdatedBy)
	var f Folder
	return f, scanFolder(row, &f)
}

const listFolders = `SELECT ` + folderColumns + ` FROM folders ORDER BY created_time DESC`

func (q *Queries) ListFolders(ctx context.Context) ([]Folder, error) {
	rows, err := q.db.Query(ctx, listFolders)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var folders []Folder
	for rows.Next() {
		var f Folder
		if err := scanFolder(rows, &f); err != nil {
			return nil, err
		}
		folders = append(folders, f)
	}
	return folders, rows.Err()
}

const listFoldersByOwner = `SELECT ` + folderColumns + ` FROM folders WHERE owner_id = $1 ORDER BY created_time DESC`

func (q *Queries) ListFoldersByOwner(ctx context.Context, ownerID string) ([]Folder, error) {
	rows, err := q.db.Query(ctx, listFoldersByOwner, ownerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var folders []Folder
	for rows.Next() {
		var f Folder
		if err := scanFolder(rows, &f); err != nil {
			return nil, err
		}
		folders = append(folders, f)
	}
	return folders, rows.Err()
}

const getFolderByID = `SELECT ` + folderColumns + ` FROM folders WHERE id = $1 LIMIT 1`

func (q *Queries) GetFolderByID(ctx context.Context, id string) (Folder, error) {
	row := q.db.QueryRow(ctx, getFolderByID, id)
	var f Folder
	return f, scanFolder(row, &f)
}

const updateFolderByID = `
UPDATE folders
SET name = $2, description = $3, domain = $4, theme = $5, icon = $6, is_locked = $7, updated_by = $8, updated_time = NOW()
WHERE id = $1
RETURNING ` + folderColumns

func (q *Queries) UpdateFolderByID(ctx context.Context, arg UpdateFolderByIDParams) (Folder, error) {
	row := q.db.QueryRow(ctx, updateFolderByID,
		arg.ID, arg.Name, arg.Description, arg.Domain, arg.Theme, arg.Icon, arg.IsLocked, arg.UpdatedBy)
	var f Folder
	return f, scanFolder(row, &f)
}

const deleteFolderByID = `DELETE FROM folders WHERE id = $1`

func (q *Queries) DeleteFolderByID(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteFolderByID, id)
	return err
}

const addSkillToFolder = `
INSERT INTO skill_folders (folder_id, skill_id, added_by)
VALUES ($1, $2, $3)
ON CONFLICT (folder_id, skill_id) DO NOTHING
`

func (q *Queries) AddSkillToFolder(ctx context.Context, arg AddSkillToFolderParams) error {
	_, err := q.db.Exec(ctx, addSkillToFolder, arg.FolderID, arg.SkillID, arg.AddedBy)
	return err
}

const removeSkillFromFolder = `DELETE FROM skill_folders WHERE folder_id = $1 AND skill_id = $2`

func (q *Queries) RemoveSkillFromFolder(ctx context.Context, arg RemoveSkillFromFolderParams) error {
	_, err := q.db.Exec(ctx, removeSkillFromFolder, arg.FolderID, arg.SkillID)
	return err
}

const listSkillsInFolder = `
SELECT s.id, s.title, s.description, s.difficulty, s.status, s.tags,
       s.created_by, s.updated_by, s.created_time, s.updated_time
FROM skills s
JOIN skill_folders sf ON sf.skill_id = s.id
WHERE sf.folder_id = $1
ORDER BY sf.added_at ASC
`

func (q *Queries) ListSkillsInFolder(ctx context.Context, folderID string) ([]Skill, error) {
	rows, err := q.db.Query(ctx, listSkillsInFolder, folderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var skills []Skill
	for rows.Next() {
		var s Skill
		if err := rows.Scan(&s.ID, &s.Title, &s.Description, &s.Difficulty, &s.Status, &s.Tags,
			&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime); err != nil {
			return nil, err
		}
		skills = append(skills, s)
	}
	return skills, rows.Err()
}

const initFoldersTable = `
CREATE TABLE IF NOT EXISTS folders (
    id VARCHAR(64) PRIMARY KEY,
    folder_type VARCHAR(20) NOT NULL DEFAULT 'teacher',
    owner_id VARCHAR(64),
    program_id VARCHAR(64),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    domain VARCHAR(100),
    theme VARCHAR(50) NOT NULL DEFAULT '',
    icon VARCHAR(50) NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitFoldersTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initFoldersTable)
	return err
}

const migrateFoldersAddTheme = `ALTER TABLE folders ADD COLUMN IF NOT EXISTS theme VARCHAR(50) NOT NULL DEFAULT ''`
const migrateFoldersAddIcon = `ALTER TABLE folders ADD COLUMN IF NOT EXISTS icon VARCHAR(50) NOT NULL DEFAULT ''`

func (q *Queries) MigrateFoldersAddThemeIcon(ctx context.Context) error {
	if _, err := q.db.Exec(ctx, migrateFoldersAddTheme); err != nil {
		return err
	}
	_, err := q.db.Exec(ctx, migrateFoldersAddIcon)
	return err
}

const migrateFoldersAddOwnership = `
ALTER TABLE folders ADD COLUMN IF NOT EXISTS folder_type VARCHAR(20) NOT NULL DEFAULT 'teacher';
ALTER TABLE folders ADD COLUMN IF NOT EXISTS owner_id VARCHAR(64);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS program_id VARCHAR(64);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE folders ADD COLUMN IF NOT EXISTS domain VARCHAR(100);
`

func (q *Queries) MigrateFoldersAddOwnership(ctx context.Context) error {
	_, err := q.db.Exec(ctx, migrateFoldersAddOwnership)
	return err
}

const initFoldersCreatedTimeIndex = `CREATE INDEX IF NOT EXISTS idx_folders_created_time ON folders (created_time DESC)`

func (q *Queries) InitFoldersCreatedTimeIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initFoldersCreatedTimeIndex)
	return err
}

const initSkillFoldersTable = `
CREATE TABLE IF NOT EXISTS skill_folders (
    folder_id VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    skill_id VARCHAR(64) NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    added_by VARCHAR(64) NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (folder_id, skill_id)
)
`

func (q *Queries) InitSkillFoldersTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSkillFoldersTable)
	return err
}

const initFolderMembersTable = `
CREATE TABLE IF NOT EXISTS folder_members (
    folder_id VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'viewer',
    added_by VARCHAR(64),
    added_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (folder_id, user_id)
)
`

func (q *Queries) InitFolderMembersTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initFolderMembersTable)
	return err
}

const addFolderMember = `
INSERT INTO folder_members (folder_id, user_id, role, added_by)
VALUES ($1, $2, $3, $4)
ON CONFLICT (folder_id, user_id) DO UPDATE SET role = EXCLUDED.role, added_by = EXCLUDED.added_by, added_time = NOW()
RETURNING folder_id, user_id, role, added_by, added_time
`

func (q *Queries) AddFolderMember(ctx context.Context, arg AddFolderMemberParams) (FolderMember, error) {
	row := q.db.QueryRow(ctx, addFolderMember, arg.FolderID, arg.UserID, arg.Role, arg.AddedBy)
	var m FolderMember
	err := row.Scan(&m.FolderID, &m.UserID, &m.Role, &m.AddedBy, &m.AddedTime)
	return m, err
}

const removeFolderMember = `DELETE FROM folder_members WHERE folder_id = $1 AND user_id = $2`

func (q *Queries) RemoveFolderMember(ctx context.Context, arg RemoveFolderMemberParams) error {
	_, err := q.db.Exec(ctx, removeFolderMember, arg.FolderID, arg.UserID)
	return err
}

const listFolderMembers = `
SELECT folder_id, user_id, role, added_by, added_time
FROM folder_members WHERE folder_id = $1 ORDER BY added_time ASC
`

func (q *Queries) ListFolderMembers(ctx context.Context, folderID string) ([]FolderMember, error) {
	rows, err := q.db.Query(ctx, listFolderMembers, folderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []FolderMember
	for rows.Next() {
		var m FolderMember
		if err := rows.Scan(&m.FolderID, &m.UserID, &m.Role, &m.AddedBy, &m.AddedTime); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

const listFoldersByMember = `
SELECT f.` + folderColumns + `
FROM folders f
JOIN folder_members fm ON fm.folder_id = f.id
WHERE fm.user_id = $1
ORDER BY fm.added_time ASC
`

func (q *Queries) ListFoldersByMember(ctx context.Context, userID string) ([]Folder, error) {
	rows, err := q.db.Query(ctx, listFoldersByMember, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var folders []Folder
	for rows.Next() {
		var f Folder
		if err := scanFolder(rows, &f); err != nil {
			return nil, err
		}
		folders = append(folders, f)
	}
	return folders, rows.Err()
}

package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// Folder represents a named collection that can hold skills.
type Folder struct {
	ID          string             `json:"id"`
	Name        string             `json:"name"`
	Description string             `json:"description"`
	Theme       string             `json:"theme"`
	Icon        string             `json:"icon"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

type CreateFolderParams struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Theme       string `json:"theme"`
	Icon        string `json:"icon"`
	CreatedBy   string `json:"created_by"`
	UpdatedBy   string `json:"updated_by"`
}

type UpdateFolderByIDParams struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Theme       string `json:"theme"`
	Icon        string `json:"icon"`
	UpdatedBy   string `json:"updated_by"`
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

const createFolder = `
INSERT INTO folders (id, name, description, theme, icon, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, name, description, theme, icon, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateFolder(ctx context.Context, arg CreateFolderParams) (Folder, error) {
	row := q.db.QueryRow(ctx, createFolder, arg.ID, arg.Name, arg.Description, arg.Theme, arg.Icon, arg.CreatedBy, arg.UpdatedBy)
	var f Folder
	err := row.Scan(&f.ID, &f.Name, &f.Description, &f.Theme, &f.Icon, &f.CreatedBy, &f.UpdatedBy, &f.CreatedTime, &f.UpdatedTime)
	return f, err
}

const listFolders = `
SELECT id, name, description, theme, icon, created_by, updated_by, created_time, updated_time
FROM folders
ORDER BY created_time DESC
`

func (q *Queries) ListFolders(ctx context.Context) ([]Folder, error) {
	rows, err := q.db.Query(ctx, listFolders)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var folders []Folder
	for rows.Next() {
		var f Folder
		if err := rows.Scan(&f.ID, &f.Name, &f.Description, &f.Theme, &f.Icon, &f.CreatedBy, &f.UpdatedBy, &f.CreatedTime, &f.UpdatedTime); err != nil {
			return nil, err
		}
		folders = append(folders, f)
	}
	return folders, rows.Err()
}

const getFolderByID = `
SELECT id, name, description, theme, icon, created_by, updated_by, created_time, updated_time
FROM folders WHERE id = $1 LIMIT 1
`

func (q *Queries) GetFolderByID(ctx context.Context, id string) (Folder, error) {
	row := q.db.QueryRow(ctx, getFolderByID, id)
	var f Folder
	err := row.Scan(&f.ID, &f.Name, &f.Description, &f.Theme, &f.Icon, &f.CreatedBy, &f.UpdatedBy, &f.CreatedTime, &f.UpdatedTime)
	return f, err
}

const updateFolderByID = `
UPDATE folders
SET name = $2, description = $3, theme = $4, icon = $5, updated_by = $6, updated_time = NOW()
WHERE id = $1
RETURNING id, name, description, theme, icon, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateFolderByID(ctx context.Context, arg UpdateFolderByIDParams) (Folder, error) {
	row := q.db.QueryRow(ctx, updateFolderByID, arg.ID, arg.Name, arg.Description, arg.Theme, arg.Icon, arg.UpdatedBy)
	var f Folder
	err := row.Scan(&f.ID, &f.Name, &f.Description, &f.Theme, &f.Icon, &f.CreatedBy, &f.UpdatedBy, &f.CreatedTime, &f.UpdatedTime)
	return f, err
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
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
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

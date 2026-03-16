package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// Space is a typed collection of items (e.g. Problems, Exercises) inside a folder.
type Space struct {
	ID          string             `json:"id"`
	FolderID    string             `json:"folder_id"`
	Name        string             `json:"name"`
	SpaceType   string             `json:"space_type"`
	Description string             `json:"description"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

// ── Space param types ────────────────────────────────────────

type CreateSpaceParams struct {
	ID          string `json:"id"`
	FolderID    string `json:"folder_id"`
	Name        string `json:"name"`
	SpaceType   string `json:"space_type"`
	Description string `json:"description"`
	CreatedBy   string `json:"created_by"`
	UpdatedBy   string `json:"updated_by"`
}

type UpdateSpaceParams struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	SpaceType   string `json:"space_type"`
	Description string `json:"description"`
	UpdatedBy   string `json:"updated_by"`
}

// ── Space queries ────────────────────────────────────────────

const createSpace = `
INSERT INTO spaces (id, folder_id, name, space_type, description, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, folder_id, name, space_type, description, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateSpace(ctx context.Context, arg CreateSpaceParams) (Space, error) {
	row := q.db.QueryRow(ctx, createSpace,
		arg.ID, arg.FolderID, arg.Name, arg.SpaceType, arg.Description, arg.CreatedBy, arg.UpdatedBy)
	var s Space
	err := row.Scan(&s.ID, &s.FolderID, &s.Name, &s.SpaceType, &s.Description,
		&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const listSpacesByFolder = `
SELECT id, folder_id, name, space_type, description, created_by, updated_by, created_time, updated_time
FROM spaces WHERE folder_id = $1 ORDER BY created_time ASC
`

func (q *Queries) ListSpacesByFolder(ctx context.Context, folderID string) ([]Space, error) {
	rows, err := q.db.Query(ctx, listSpacesByFolder, folderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var spaces []Space
	for rows.Next() {
		var s Space
		if err := rows.Scan(&s.ID, &s.FolderID, &s.Name, &s.SpaceType, &s.Description,
			&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime); err != nil {
			return nil, err
		}
		spaces = append(spaces, s)
	}
	return spaces, rows.Err()
}

const getSpaceByID = `
SELECT id, folder_id, name, space_type, description, created_by, updated_by, created_time, updated_time
FROM spaces WHERE id = $1 LIMIT 1
`

func (q *Queries) GetSpaceByID(ctx context.Context, id string) (Space, error) {
	row := q.db.QueryRow(ctx, getSpaceByID, id)
	var s Space
	err := row.Scan(&s.ID, &s.FolderID, &s.Name, &s.SpaceType, &s.Description,
		&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const updateSpace = `
UPDATE spaces
SET name = $2, space_type = $3, description = $4, updated_by = $5, updated_time = NOW()
WHERE id = $1
RETURNING id, folder_id, name, space_type, description, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateSpace(ctx context.Context, arg UpdateSpaceParams) (Space, error) {
	row := q.db.QueryRow(ctx, updateSpace, arg.ID, arg.Name, arg.SpaceType, arg.Description, arg.UpdatedBy)
	var s Space
	err := row.Scan(&s.ID, &s.FolderID, &s.Name, &s.SpaceType, &s.Description,
		&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const deleteSpace = `DELETE FROM spaces WHERE id = $1`

func (q *Queries) DeleteSpace(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteSpace, id)
	return err
}

// ── Init queries ─────────────────────────────────────────────

const initSpacesTable = `
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
)
`

func (q *Queries) InitSpacesTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSpacesTable)
	return err
}

const initSpacesFolderIndex = `CREATE INDEX IF NOT EXISTS idx_spaces_folder_id ON spaces (folder_id)`

func (q *Queries) InitSpacesFolderIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSpacesFolderIndex)
	return err
}

const initSpacesCreatedTimeIndex = `CREATE INDEX IF NOT EXISTS idx_spaces_created_time ON spaces (created_time DESC)`

func (q *Queries) InitSpacesCreatedTimeIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSpacesCreatedTimeIndex)
	return err
}

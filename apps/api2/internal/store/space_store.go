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

// SpaceItem is a single entry inside a Space (e.g. "Problem 1").
type SpaceItem struct {
	ID          string             `json:"id"`
	SpaceID     string             `json:"space_id"`
	Title       string             `json:"title"`
	Content     string             `json:"content"`
	Position    int32              `json:"position"`
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

// ── SpaceItem param types ────────────────────────────────────

type CreateSpaceItemParams struct {
	ID        string `json:"id"`
	SpaceID   string `json:"space_id"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	Position  int32  `json:"position"`
	CreatedBy string `json:"created_by"`
	UpdatedBy string `json:"updated_by"`
}

type UpdateSpaceItemParams struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	Position  int32  `json:"position"`
	UpdatedBy string `json:"updated_by"`
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

// ── SpaceItem queries ────────────────────────────────────────

const createSpaceItem = `
INSERT INTO space_items (id, space_id, title, content, position, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, space_id, title, content, position, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateSpaceItem(ctx context.Context, arg CreateSpaceItemParams) (SpaceItem, error) {
	row := q.db.QueryRow(ctx, createSpaceItem,
		arg.ID, arg.SpaceID, arg.Title, arg.Content, arg.Position, arg.CreatedBy, arg.UpdatedBy)
	var si SpaceItem
	err := row.Scan(&si.ID, &si.SpaceID, &si.Title, &si.Content, &si.Position,
		&si.CreatedBy, &si.UpdatedBy, &si.CreatedTime, &si.UpdatedTime)
	return si, err
}

const listSpaceItems = `
SELECT id, space_id, title, content, position, created_by, updated_by, created_time, updated_time
FROM space_items WHERE space_id = $1 ORDER BY position ASC, created_time ASC
`

func (q *Queries) ListSpaceItems(ctx context.Context, spaceID string) ([]SpaceItem, error) {
	rows, err := q.db.Query(ctx, listSpaceItems, spaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []SpaceItem
	for rows.Next() {
		var si SpaceItem
		if err := rows.Scan(&si.ID, &si.SpaceID, &si.Title, &si.Content, &si.Position,
			&si.CreatedBy, &si.UpdatedBy, &si.CreatedTime, &si.UpdatedTime); err != nil {
			return nil, err
		}
		items = append(items, si)
	}
	return items, rows.Err()
}

const getSpaceItemByID = `
SELECT id, space_id, title, content, position, created_by, updated_by, created_time, updated_time
FROM space_items WHERE id = $1 LIMIT 1
`

func (q *Queries) GetSpaceItemByID(ctx context.Context, id string) (SpaceItem, error) {
	row := q.db.QueryRow(ctx, getSpaceItemByID, id)
	var si SpaceItem
	err := row.Scan(&si.ID, &si.SpaceID, &si.Title, &si.Content, &si.Position,
		&si.CreatedBy, &si.UpdatedBy, &si.CreatedTime, &si.UpdatedTime)
	return si, err
}

const updateSpaceItem = `
UPDATE space_items
SET title = $2, content = $3, position = $4, updated_by = $5, updated_time = NOW()
WHERE id = $1
RETURNING id, space_id, title, content, position, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateSpaceItem(ctx context.Context, arg UpdateSpaceItemParams) (SpaceItem, error) {
	row := q.db.QueryRow(ctx, updateSpaceItem, arg.ID, arg.Title, arg.Content, arg.Position, arg.UpdatedBy)
	var si SpaceItem
	err := row.Scan(&si.ID, &si.SpaceID, &si.Title, &si.Content, &si.Position,
		&si.CreatedBy, &si.UpdatedBy, &si.CreatedTime, &si.UpdatedTime)
	return si, err
}

const deleteSpaceItem = `DELETE FROM space_items WHERE id = $1`

func (q *Queries) DeleteSpaceItem(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteSpaceItem, id)
	return err
}

const countSpaceItemsBySpace = `SELECT COUNT(*) FROM space_items WHERE space_id = $1`

func (q *Queries) CountSpaceItemsBySpace(ctx context.Context, spaceID string) (int64, error) {
	var n int64
	err := q.db.QueryRow(ctx, countSpaceItemsBySpace, spaceID).Scan(&n)
	return n, err
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

const initSpaceItemsTable = `
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
)
`

func (q *Queries) InitSpaceItemsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSpaceItemsTable)
	return err
}

const initSpaceItemsSpaceIndex = `CREATE INDEX IF NOT EXISTS idx_space_items_space_id ON space_items (space_id)`

func (q *Queries) InitSpaceItemsSpaceIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSpaceItemsSpaceIndex)
	return err
}

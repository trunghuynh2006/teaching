package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// Source is a piece of content belonging to a folder.
type Source struct {
	ID          string             `json:"id"`
	FolderID    string             `json:"folder_id"`
	Title       string             `json:"title"`
	Content     string             `json:"content"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

type CreateSourceParams struct {
	ID        string `json:"id"`
	FolderID  string `json:"folder_id"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	CreatedBy string `json:"created_by"`
	UpdatedBy string `json:"updated_by"`
}

type UpdateSourceParams struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	UpdatedBy string `json:"updated_by"`
}

const createSource = `
INSERT INTO sources (id, folder_id, title, content, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, folder_id, title, content, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateSource(ctx context.Context, arg CreateSourceParams) (Source, error) {
	row := q.db.QueryRow(ctx, createSource,
		arg.ID, arg.FolderID, arg.Title, arg.Content, arg.CreatedBy, arg.UpdatedBy)
	var s Source
	err := row.Scan(&s.ID, &s.FolderID, &s.Title, &s.Content, &s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const listSourcesByFolder = `
SELECT id, folder_id, title, content, created_by, updated_by, created_time, updated_time
FROM sources
WHERE folder_id = $1
ORDER BY created_time ASC
`

func (q *Queries) ListSourcesByFolder(ctx context.Context, folderID string) ([]Source, error) {
	rows, err := q.db.Query(ctx, listSourcesByFolder, folderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sources []Source
	for rows.Next() {
		var s Source
		if err := rows.Scan(&s.ID, &s.FolderID, &s.Title, &s.Content, &s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime); err != nil {
			return nil, err
		}
		sources = append(sources, s)
	}
	return sources, rows.Err()
}

const getSourceByID = `
SELECT id, folder_id, title, content, created_by, updated_by, created_time, updated_time
FROM sources WHERE id = $1 LIMIT 1
`

func (q *Queries) GetSourceByID(ctx context.Context, id string) (Source, error) {
	row := q.db.QueryRow(ctx, getSourceByID, id)
	var s Source
	err := row.Scan(&s.ID, &s.FolderID, &s.Title, &s.Content, &s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const updateSource = `
UPDATE sources
SET title = $2, content = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, folder_id, title, content, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateSource(ctx context.Context, arg UpdateSourceParams) (Source, error) {
	row := q.db.QueryRow(ctx, updateSource, arg.ID, arg.Title, arg.Content, arg.UpdatedBy)
	var s Source
	err := row.Scan(&s.ID, &s.FolderID, &s.Title, &s.Content, &s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const deleteSource = `DELETE FROM sources WHERE id = $1`

func (q *Queries) DeleteSource(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteSource, id)
	return err
}

const initSourcesTable = `
CREATE TABLE IF NOT EXISTS sources (
    id VARCHAR(64) PRIMARY KEY,
    folder_id VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitSourcesTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSourcesTable)
	return err
}

const initSourcesFolderIndex = `CREATE INDEX IF NOT EXISTS idx_sources_folder_id ON sources (folder_id)`

func (q *Queries) InitSourcesFolderIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSourcesFolderIndex)
	return err
}

const initSourcesCreatedTimeIndex = `CREATE INDEX IF NOT EXISTS idx_sources_created_time ON sources (created_time DESC)`

func (q *Queries) InitSourcesCreatedTimeIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSourcesCreatedTimeIndex)
	return err
}

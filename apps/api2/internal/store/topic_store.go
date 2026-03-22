package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

type Topic struct {
	ID          string             `json:"id"`
	Name        string             `json:"name"`
	FolderID    string             `json:"folder_id"`
	Description string             `json:"description"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

type CreateTopicParams struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	FolderID    string `json:"folder_id"`
	Description string `json:"description"`
	CreatedBy   string `json:"created_by"`
	UpdatedBy   string `json:"updated_by"`
}

type UpdateTopicParams struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	UpdatedBy   string `json:"updated_by"`
}

const createTopic = `
INSERT INTO topics (id, name, folder_id, description, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, name, folder_id, description, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateTopic(ctx context.Context, arg CreateTopicParams) (Topic, error) {
	row := q.db.QueryRow(ctx, createTopic,
		arg.ID, arg.Name, arg.FolderID, arg.Description, arg.CreatedBy, arg.UpdatedBy)
	var t Topic
	err := row.Scan(&t.ID, &t.Name, &t.FolderID, &t.Description,
		&t.CreatedBy, &t.UpdatedBy, &t.CreatedTime, &t.UpdatedTime)
	return t, err
}

const listTopicsByFolder = `
SELECT id, name, folder_id, description, created_by, updated_by, created_time, updated_time
FROM topics WHERE folder_id = $1 ORDER BY created_time ASC
`

func (q *Queries) ListTopicsByFolder(ctx context.Context, folderID string) ([]Topic, error) {
	rows, err := q.db.Query(ctx, listTopicsByFolder, folderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var topics []Topic
	for rows.Next() {
		var t Topic
		if err := rows.Scan(&t.ID, &t.Name, &t.FolderID, &t.Description,
			&t.CreatedBy, &t.UpdatedBy, &t.CreatedTime, &t.UpdatedTime); err != nil {
			return nil, err
		}
		topics = append(topics, t)
	}
	return topics, rows.Err()
}

const getTopicByID = `
SELECT id, name, folder_id, description, created_by, updated_by, created_time, updated_time
FROM topics WHERE id = $1 LIMIT 1
`

func (q *Queries) GetTopicByID(ctx context.Context, id string) (Topic, error) {
	row := q.db.QueryRow(ctx, getTopicByID, id)
	var t Topic
	err := row.Scan(&t.ID, &t.Name, &t.FolderID, &t.Description,
		&t.CreatedBy, &t.UpdatedBy, &t.CreatedTime, &t.UpdatedTime)
	return t, err
}

const updateTopic = `
UPDATE topics
SET name = $2, description = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, name, folder_id, description, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateTopic(ctx context.Context, arg UpdateTopicParams) (Topic, error) {
	row := q.db.QueryRow(ctx, updateTopic, arg.ID, arg.Name, arg.Description, arg.UpdatedBy)
	var t Topic
	err := row.Scan(&t.ID, &t.Name, &t.FolderID, &t.Description,
		&t.CreatedBy, &t.UpdatedBy, &t.CreatedTime, &t.UpdatedTime)
	return t, err
}

const deleteTopic = `DELETE FROM topics WHERE id = $1`

func (q *Queries) DeleteTopic(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteTopic, id)
	return err
}

const initTopicsTable = `
CREATE TABLE IF NOT EXISTS topics (
    id           VARCHAR(64) PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    folder_id    VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    description  TEXT NOT NULL DEFAULT '',
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    updated_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitTopicsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initTopicsTable)
	return err
}

const initTopicsFolderIndex = `CREATE INDEX IF NOT EXISTS idx_topics_folder_id ON topics (folder_id)`

func (q *Queries) InitTopicsFolderIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initTopicsFolderIndex)
	return err
}

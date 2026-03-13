package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// Knowledge is a text-based piece of content belonging to a folder.
type Knowledge struct {
	ID          string             `json:"id"`
	FolderID    string             `json:"folder_id"`
	Title       string             `json:"title"`
	Content     string             `json:"content"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

type CreateKnowledgeParams struct {
	ID       string `json:"id"`
	FolderID string `json:"folder_id"`
	Title    string `json:"title"`
	Content  string `json:"content"`
	CreatedBy string `json:"created_by"`
	UpdatedBy string `json:"updated_by"`
}

type UpdateKnowledgeParams struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	UpdatedBy string `json:"updated_by"`
}

const createKnowledge = `
INSERT INTO knowledges (id, folder_id, title, content, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, folder_id, title, content, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateKnowledge(ctx context.Context, arg CreateKnowledgeParams) (Knowledge, error) {
	row := q.db.QueryRow(ctx, createKnowledge,
		arg.ID, arg.FolderID, arg.Title, arg.Content, arg.CreatedBy, arg.UpdatedBy)
	var k Knowledge
	err := row.Scan(&k.ID, &k.FolderID, &k.Title, &k.Content, &k.CreatedBy, &k.UpdatedBy, &k.CreatedTime, &k.UpdatedTime)
	return k, err
}

const listKnowledgesByFolder = `
SELECT id, folder_id, title, content, created_by, updated_by, created_time, updated_time
FROM knowledges
WHERE folder_id = $1
ORDER BY created_time ASC
`

func (q *Queries) ListKnowledgesByFolder(ctx context.Context, folderID string) ([]Knowledge, error) {
	rows, err := q.db.Query(ctx, listKnowledgesByFolder, folderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var knowledges []Knowledge
	for rows.Next() {
		var k Knowledge
		if err := rows.Scan(&k.ID, &k.FolderID, &k.Title, &k.Content, &k.CreatedBy, &k.UpdatedBy, &k.CreatedTime, &k.UpdatedTime); err != nil {
			return nil, err
		}
		knowledges = append(knowledges, k)
	}
	return knowledges, rows.Err()
}

const getKnowledgeByID = `
SELECT id, folder_id, title, content, created_by, updated_by, created_time, updated_time
FROM knowledges WHERE id = $1 LIMIT 1
`

func (q *Queries) GetKnowledgeByID(ctx context.Context, id string) (Knowledge, error) {
	row := q.db.QueryRow(ctx, getKnowledgeByID, id)
	var k Knowledge
	err := row.Scan(&k.ID, &k.FolderID, &k.Title, &k.Content, &k.CreatedBy, &k.UpdatedBy, &k.CreatedTime, &k.UpdatedTime)
	return k, err
}

const updateKnowledge = `
UPDATE knowledges
SET title = $2, content = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, folder_id, title, content, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateKnowledge(ctx context.Context, arg UpdateKnowledgeParams) (Knowledge, error) {
	row := q.db.QueryRow(ctx, updateKnowledge, arg.ID, arg.Title, arg.Content, arg.UpdatedBy)
	var k Knowledge
	err := row.Scan(&k.ID, &k.FolderID, &k.Title, &k.Content, &k.CreatedBy, &k.UpdatedBy, &k.CreatedTime, &k.UpdatedTime)
	return k, err
}

const deleteKnowledge = `DELETE FROM knowledges WHERE id = $1`

func (q *Queries) DeleteKnowledge(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteKnowledge, id)
	return err
}

const initKnowledgesTable = `
CREATE TABLE IF NOT EXISTS knowledges (
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

func (q *Queries) InitKnowledgesTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initKnowledgesTable)
	return err
}

const initKnowledgesFolderIndex = `CREATE INDEX IF NOT EXISTS idx_knowledges_folder_id ON knowledges (folder_id)`

func (q *Queries) InitKnowledgesFolderIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initKnowledgesFolderIndex)
	return err
}

const initKnowledgesCreatedTimeIndex = `CREATE INDEX IF NOT EXISTS idx_knowledges_created_time ON knowledges (created_time DESC)`

func (q *Queries) InitKnowledgesCreatedTimeIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initKnowledgesCreatedTimeIndex)
	return err
}

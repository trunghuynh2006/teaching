package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// ─── LearningPath ────────────────────────────────────────────────────────────

type LearningPath struct {
	ID          string             `json:"id"`
	Title       string             `json:"title"`
	Description string             `json:"description"`
	Domain      string             `json:"domain"`
	Status      string             `json:"status"` // draft | published | archived
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

type CreateLearningPathParams struct {
	ID          string
	Title       string
	Description string
	Domain      string
	Status      string
	CreatedBy   string
	UpdatedBy   string
}

type UpdateLearningPathParams struct {
	ID          string
	Title       string
	Description string
	Domain      string
	Status      string
	UpdatedBy   string
}

const learningPathColumns = `id, title, description, domain, status, created_by, updated_by, created_time, updated_time`

func scanLearningPath(row interface{ Scan(...any) error }) (LearningPath, error) {
	var p LearningPath
	err := row.Scan(&p.ID, &p.Title, &p.Description, &p.Domain, &p.Status,
		&p.CreatedBy, &p.UpdatedBy, &p.CreatedTime, &p.UpdatedTime)
	return p, err
}

const initLearningPathsTable = `
CREATE TABLE IF NOT EXISTS learning_paths (
    id           VARCHAR(64) PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    description  TEXT NOT NULL DEFAULT '',
    domain       VARCHAR(100) NOT NULL DEFAULT '',
    status       VARCHAR(20) NOT NULL DEFAULT 'draft',
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    updated_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_lp_status CHECK (status IN ('draft', 'published', 'archived'))
)
`

func (q *Queries) InitLearningPathsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initLearningPathsTable)
	return err
}

const initLearningPathsDomainIndex = `CREATE INDEX IF NOT EXISTS idx_learning_paths_domain ON learning_paths (domain)`

func (q *Queries) InitLearningPathsDomainIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initLearningPathsDomainIndex)
	return err
}

const createLearningPath = `
INSERT INTO learning_paths (id, title, description, domain, status, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING ` + learningPathColumns

func (q *Queries) CreateLearningPath(ctx context.Context, arg CreateLearningPathParams) (LearningPath, error) {
	return scanLearningPath(q.db.QueryRow(ctx, createLearningPath,
		arg.ID, arg.Title, arg.Description, arg.Domain, arg.Status, arg.CreatedBy, arg.UpdatedBy))
}

const listLearningPaths = `SELECT ` + learningPathColumns + ` FROM learning_paths ORDER BY created_time DESC`

func (q *Queries) ListLearningPaths(ctx context.Context) ([]LearningPath, error) {
	rows, err := q.db.Query(ctx, listLearningPaths)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []LearningPath
	for rows.Next() {
		p, err := scanLearningPath(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

const listLearningPathsByDomain = `SELECT ` + learningPathColumns + ` FROM learning_paths WHERE domain = $1 ORDER BY created_time DESC`

func (q *Queries) ListLearningPathsByDomain(ctx context.Context, domain string) ([]LearningPath, error) {
	rows, err := q.db.Query(ctx, listLearningPathsByDomain, domain)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []LearningPath
	for rows.Next() {
		p, err := scanLearningPath(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

const getLearningPathByID = `SELECT ` + learningPathColumns + ` FROM learning_paths WHERE id = $1 LIMIT 1`

func (q *Queries) GetLearningPathByID(ctx context.Context, id string) (LearningPath, error) {
	return scanLearningPath(q.db.QueryRow(ctx, getLearningPathByID, id))
}

const updateLearningPath = `
UPDATE learning_paths
SET title = $2, description = $3, domain = $4, status = $5, updated_by = $6, updated_time = NOW()
WHERE id = $1
RETURNING ` + learningPathColumns

func (q *Queries) UpdateLearningPath(ctx context.Context, arg UpdateLearningPathParams) (LearningPath, error) {
	return scanLearningPath(q.db.QueryRow(ctx, updateLearningPath,
		arg.ID, arg.Title, arg.Description, arg.Domain, arg.Status, arg.UpdatedBy))
}

const deleteLearningPath = `DELETE FROM learning_paths WHERE id = $1`

func (q *Queries) DeleteLearningPath(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteLearningPath, id)
	return err
}

// ─── LearningPathStep ────────────────────────────────────────────────────────

type LearningPathStep struct {
	ID         string             `json:"id"`
	PathID     string             `json:"path_id"`
	ConceptID  string             `json:"concept_id"`
	Position   int                `json:"position"`
	Note       string             `json:"note"`
	CreatedBy  string             `json:"created_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
}

// LearningPathStepWithConcept embeds a Concept for list responses.
type LearningPathStepWithConcept struct {
	LearningPathStep
	Concept Concept `json:"concept"`
}

type AddLearningPathStepParams struct {
	ID        string
	PathID    string
	ConceptID string
	Position  int
	Note      string
	CreatedBy string
}

const stepColumns = `s.id, s.path_id, s.concept_id, s.position, s.note, s.created_by, s.created_time`

const initLearningPathStepsTable = `
CREATE TABLE IF NOT EXISTS learning_path_steps (
    id           VARCHAR(64) PRIMARY KEY,
    path_id      VARCHAR(64) NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    position     INT NOT NULL DEFAULT 0,
    note         TEXT NOT NULL DEFAULT '',
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (path_id, concept_id)
)
`

func (q *Queries) InitLearningPathStepsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initLearningPathStepsTable)
	return err
}

const initLearningPathStepsPathIndex = `CREATE INDEX IF NOT EXISTS idx_lp_steps_path_id ON learning_path_steps (path_id)`

func (q *Queries) InitLearningPathStepsPathIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initLearningPathStepsPathIndex)
	return err
}

const addLearningPathStep = `
INSERT INTO learning_path_steps (id, path_id, concept_id, position, note, created_by)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (path_id, concept_id) DO NOTHING
`

func (q *Queries) AddLearningPathStep(ctx context.Context, arg AddLearningPathStepParams) error {
	_, err := q.db.Exec(ctx, addLearningPathStep,
		arg.ID, arg.PathID, arg.ConceptID, arg.Position, arg.Note, arg.CreatedBy)
	return err
}

const removeLearningPathStep = `DELETE FROM learning_path_steps WHERE path_id = $1 AND concept_id = $2`

func (q *Queries) RemoveLearningPathStep(ctx context.Context, pathID, conceptID string) error {
	_, err := q.db.Exec(ctx, removeLearningPathStep, pathID, conceptID)
	return err
}

const reorderLearningPathStep = `
UPDATE learning_path_steps SET position = $3 WHERE path_id = $1 AND concept_id = $2
`

func (q *Queries) ReorderLearningPathStep(ctx context.Context, pathID, conceptID string, position int) error {
	_, err := q.db.Exec(ctx, reorderLearningPathStep, pathID, conceptID, position)
	return err
}

const listLearningPathSteps = `
SELECT ` + stepColumns + `, ` + conceptColumnsQ + `
FROM learning_path_steps s
JOIN concepts c ON c.id = s.concept_id
WHERE s.path_id = $1
ORDER BY s.position ASC, s.created_time ASC
`

func (q *Queries) ListLearningPathSteps(ctx context.Context, pathID string) ([]LearningPathStepWithConcept, error) {
	rows, err := q.db.Query(ctx, listLearningPathSteps, pathID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []LearningPathStepWithConcept
	for rows.Next() {
		var row LearningPathStepWithConcept
		err := rows.Scan(
			&row.ID, &row.PathID, &row.ConceptID, &row.Position, &row.Note, &row.CreatedBy, &row.CreatedTime,
			&row.Concept.ID, &row.Concept.CanonicalName, &row.Concept.Domain,
			&row.Concept.Description, &row.Concept.Example, &row.Concept.Analogy,
			&row.Concept.CommonMistakes, &row.Concept.Tags, &row.Concept.Level, &row.Concept.Scope,
			&row.Concept.ParentConceptID, &row.Concept.CreatedBy, &row.Concept.UpdatedBy,
			&row.Concept.CreatedTime, &row.Concept.UpdatedTime,
		)
		if err != nil {
			return nil, err
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

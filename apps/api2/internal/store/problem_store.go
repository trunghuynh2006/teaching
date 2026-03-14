package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// Problem is a worked problem attached to a SpaceItem, with a question, solution summary, and steps.
type Problem struct {
	ID          string             `json:"id"`
	SpaceItemID string             `json:"space_item_id"`
	Question    string             `json:"question"`
	Solution    string             `json:"solution"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

// ProblemStep is one step in the solution of a Problem.
type ProblemStep struct {
	ID          string             `json:"id"`
	ProblemID   string             `json:"problem_id"`
	Body        string             `json:"body"`
	Position    int32              `json:"position"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

// ── Problem param types ──────────────────────────────────────

type CreateProblemParams struct {
	ID          string `json:"id"`
	SpaceItemID string `json:"space_item_id"`
	Question    string `json:"question"`
	Solution    string `json:"solution"`
	CreatedBy   string `json:"created_by"`
	UpdatedBy   string `json:"updated_by"`
}

type UpdateProblemParams struct {
	ID        string `json:"id"`
	Question  string `json:"question"`
	Solution  string `json:"solution"`
	UpdatedBy string `json:"updated_by"`
}

// ── ProblemStep param types ──────────────────────────────────

type CreateProblemStepParams struct {
	ID        string `json:"id"`
	ProblemID string `json:"problem_id"`
	Body      string `json:"body"`
	Position  int32  `json:"position"`
	CreatedBy string `json:"created_by"`
	UpdatedBy string `json:"updated_by"`
}

type UpdateProblemStepParams struct {
	ID        string `json:"id"`
	Body      string `json:"body"`
	Position  int32  `json:"position"`
	UpdatedBy string `json:"updated_by"`
}

// ── Problem queries ──────────────────────────────────────────

const createProblem = `
INSERT INTO problems (id, space_item_id, question, solution, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, space_item_id, question, solution, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateProblem(ctx context.Context, arg CreateProblemParams) (Problem, error) {
	row := q.db.QueryRow(ctx, createProblem,
		arg.ID, arg.SpaceItemID, arg.Question, arg.Solution, arg.CreatedBy, arg.UpdatedBy)
	var p Problem
	err := row.Scan(&p.ID, &p.SpaceItemID, &p.Question, &p.Solution,
		&p.CreatedBy, &p.UpdatedBy, &p.CreatedTime, &p.UpdatedTime)
	return p, err
}

const listProblemsBySpaceItem = `
SELECT id, space_item_id, question, solution, created_by, updated_by, created_time, updated_time
FROM problems WHERE space_item_id = $1 ORDER BY created_time ASC
`

func (q *Queries) ListProblemsBySpaceItem(ctx context.Context, spaceItemID string) ([]Problem, error) {
	rows, err := q.db.Query(ctx, listProblemsBySpaceItem, spaceItemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var problems []Problem
	for rows.Next() {
		var p Problem
		if err := rows.Scan(&p.ID, &p.SpaceItemID, &p.Question, &p.Solution,
			&p.CreatedBy, &p.UpdatedBy, &p.CreatedTime, &p.UpdatedTime); err != nil {
			return nil, err
		}
		problems = append(problems, p)
	}
	return problems, rows.Err()
}

const getProblemByID = `
SELECT id, space_item_id, question, solution, created_by, updated_by, created_time, updated_time
FROM problems WHERE id = $1 LIMIT 1
`

func (q *Queries) GetProblemByID(ctx context.Context, id string) (Problem, error) {
	row := q.db.QueryRow(ctx, getProblemByID, id)
	var p Problem
	err := row.Scan(&p.ID, &p.SpaceItemID, &p.Question, &p.Solution,
		&p.CreatedBy, &p.UpdatedBy, &p.CreatedTime, &p.UpdatedTime)
	return p, err
}

const updateProblem = `
UPDATE problems
SET question = $2, solution = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, space_item_id, question, solution, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateProblem(ctx context.Context, arg UpdateProblemParams) (Problem, error) {
	row := q.db.QueryRow(ctx, updateProblem, arg.ID, arg.Question, arg.Solution, arg.UpdatedBy)
	var p Problem
	err := row.Scan(&p.ID, &p.SpaceItemID, &p.Question, &p.Solution,
		&p.CreatedBy, &p.UpdatedBy, &p.CreatedTime, &p.UpdatedTime)
	return p, err
}

const deleteProblem = `DELETE FROM problems WHERE id = $1`

func (q *Queries) DeleteProblem(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteProblem, id)
	return err
}

// ── ProblemStep queries ──────────────────────────────────────

const createProblemStep = `
INSERT INTO problem_steps (id, problem_id, body, position, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, problem_id, body, position, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateProblemStep(ctx context.Context, arg CreateProblemStepParams) (ProblemStep, error) {
	row := q.db.QueryRow(ctx, createProblemStep,
		arg.ID, arg.ProblemID, arg.Body, arg.Position, arg.CreatedBy, arg.UpdatedBy)
	var s ProblemStep
	err := row.Scan(&s.ID, &s.ProblemID, &s.Body, &s.Position,
		&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const listProblemSteps = `
SELECT id, problem_id, body, position, created_by, updated_by, created_time, updated_time
FROM problem_steps WHERE problem_id = $1 ORDER BY position ASC, created_time ASC
`

func (q *Queries) ListProblemSteps(ctx context.Context, problemID string) ([]ProblemStep, error) {
	rows, err := q.db.Query(ctx, listProblemSteps, problemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var steps []ProblemStep
	for rows.Next() {
		var s ProblemStep
		if err := rows.Scan(&s.ID, &s.ProblemID, &s.Body, &s.Position,
			&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime); err != nil {
			return nil, err
		}
		steps = append(steps, s)
	}
	return steps, rows.Err()
}

const getProblemStepByID = `
SELECT id, problem_id, body, position, created_by, updated_by, created_time, updated_time
FROM problem_steps WHERE id = $1 LIMIT 1
`

func (q *Queries) GetProblemStepByID(ctx context.Context, id string) (ProblemStep, error) {
	row := q.db.QueryRow(ctx, getProblemStepByID, id)
	var s ProblemStep
	err := row.Scan(&s.ID, &s.ProblemID, &s.Body, &s.Position,
		&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const updateProblemStep = `
UPDATE problem_steps
SET body = $2, position = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, problem_id, body, position, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateProblemStep(ctx context.Context, arg UpdateProblemStepParams) (ProblemStep, error) {
	row := q.db.QueryRow(ctx, updateProblemStep, arg.ID, arg.Body, arg.Position, arg.UpdatedBy)
	var s ProblemStep
	err := row.Scan(&s.ID, &s.ProblemID, &s.Body, &s.Position,
		&s.CreatedBy, &s.UpdatedBy, &s.CreatedTime, &s.UpdatedTime)
	return s, err
}

const deleteProblemStep = `DELETE FROM problem_steps WHERE id = $1`

func (q *Queries) DeleteProblemStep(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteProblemStep, id)
	return err
}

const countProblemSteps = `SELECT COUNT(*) FROM problem_steps WHERE problem_id = $1`

func (q *Queries) CountProblemSteps(ctx context.Context, problemID string) (int64, error) {
	var n int64
	err := q.db.QueryRow(ctx, countProblemSteps, problemID).Scan(&n)
	return n, err
}

// ── Init queries ─────────────────────────────────────────────

const initProblemsTable = `
CREATE TABLE IF NOT EXISTS problems (
    id VARCHAR(64) PRIMARY KEY,
    space_item_id VARCHAR(64) NOT NULL REFERENCES space_items(id) ON DELETE CASCADE,
    question TEXT NOT NULL DEFAULT '',
    solution TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitProblemsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initProblemsTable)
	return err
}

const initProblemsSpaceItemIndex = `CREATE INDEX IF NOT EXISTS idx_problems_space_item_id ON problems (space_item_id)`

func (q *Queries) InitProblemsSpaceItemIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initProblemsSpaceItemIndex)
	return err
}

const initProblemStepsTable = `
CREATE TABLE IF NOT EXISTS problem_steps (
    id VARCHAR(64) PRIMARY KEY,
    problem_id VARCHAR(64) NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
    body TEXT NOT NULL DEFAULT '',
    position INT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitProblemStepsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initProblemStepsTable)
	return err
}

const initProblemStepsProblemIndex = `CREATE INDEX IF NOT EXISTS idx_problem_steps_problem_id ON problem_steps (problem_id)`

func (q *Queries) InitProblemStepsProblemIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initProblemStepsProblemIndex)
	return err
}

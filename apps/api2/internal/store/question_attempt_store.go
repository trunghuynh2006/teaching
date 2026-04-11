package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// QuestionAttempt records a single answer submission by a user.
type QuestionAttempt struct {
	ID                string             `json:"id"`
	QuestionID        string             `json:"question_id"`
	SpaceID           string             `json:"space_id"`
	Username          string             `json:"username"`
	SelectedAnswerIDs []string           `json:"selected_answer_ids"`
	IsCorrect         bool               `json:"is_correct"`
	AnsweredAt        pgtype.Timestamptz `json:"answered_at"`
}

// QuestionAttemptStats summarises attempt results for one question.
type QuestionAttemptStats struct {
	QuestionID   string `json:"question_id"`
	TotalCount   int64  `json:"total_count"`
	CorrectCount int64  `json:"correct_count"`
}

// ── Param types ───────────────────────────────────────────────

type CreateQuestionAttemptParams struct {
	ID                string   `json:"id"`
	QuestionID        string   `json:"question_id"`
	SpaceID           string   `json:"space_id"`
	Username          string   `json:"username"`
	SelectedAnswerIDs []string `json:"selected_answer_ids"`
	IsCorrect         bool     `json:"is_correct"`
}

// ── Queries ───────────────────────────────────────────────────

const createQuestionAttempt = `
INSERT INTO question_attempts (id, question_id, space_id, username, selected_answer_ids, is_correct)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, question_id, space_id, username, selected_answer_ids, is_correct, answered_at
`

func (q *Queries) CreateQuestionAttempt(ctx context.Context, arg CreateQuestionAttemptParams) (QuestionAttempt, error) {
	row := q.db.QueryRow(ctx, createQuestionAttempt,
		arg.ID, arg.QuestionID, arg.SpaceID, arg.Username, arg.SelectedAnswerIDs, arg.IsCorrect)
	var a QuestionAttempt
	err := row.Scan(&a.ID, &a.QuestionID, &a.SpaceID, &a.Username,
		&a.SelectedAnswerIDs, &a.IsCorrect, &a.AnsweredAt)
	return a, err
}

const listAttemptsBySpace = `
SELECT id, question_id, space_id, username, selected_answer_ids, is_correct, answered_at
FROM question_attempts
WHERE space_id = $1
ORDER BY answered_at DESC
LIMIT 500
`

func (q *Queries) ListAttemptsBySpace(ctx context.Context, spaceID string) ([]QuestionAttempt, error) {
	rows, err := q.db.Query(ctx, listAttemptsBySpace, spaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []QuestionAttempt
	for rows.Next() {
		var a QuestionAttempt
		if err := rows.Scan(&a.ID, &a.QuestionID, &a.SpaceID, &a.Username,
			&a.SelectedAnswerIDs, &a.IsCorrect, &a.AnsweredAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

const listMySpaceAttempts = `
SELECT id, question_id, space_id, username, selected_answer_ids, is_correct, answered_at
FROM question_attempts
WHERE space_id = $1 AND username = $2
ORDER BY answered_at DESC
`

func (q *Queries) ListMySpaceAttempts(ctx context.Context, spaceID, username string) ([]QuestionAttempt, error) {
	rows, err := q.db.Query(ctx, listMySpaceAttempts, spaceID, username)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []QuestionAttempt
	for rows.Next() {
		var a QuestionAttempt
		if err := rows.Scan(&a.ID, &a.QuestionID, &a.SpaceID, &a.Username,
			&a.SelectedAnswerIDs, &a.IsCorrect, &a.AnsweredAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

const getSpaceAttemptStats = `
SELECT question_id,
       COUNT(*)                          AS total_count,
       COUNT(*) FILTER (WHERE is_correct) AS correct_count
FROM question_attempts
WHERE space_id = $1
GROUP BY question_id
`

func (q *Queries) GetSpaceAttemptStats(ctx context.Context, spaceID string) ([]QuestionAttemptStats, error) {
	rows, err := q.db.Query(ctx, getSpaceAttemptStats, spaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []QuestionAttemptStats
	for rows.Next() {
		var s QuestionAttemptStats
		if err := rows.Scan(&s.QuestionID, &s.TotalCount, &s.CorrectCount); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ── Init / Migrate ─────────────────────────────────────────────

const initQuestionAttemptsTable = `
CREATE TABLE IF NOT EXISTS question_attempts (
    id VARCHAR(64) PRIMARY KEY,
    question_id VARCHAR(64) NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    space_id VARCHAR(64) NOT NULL,
    username VARCHAR(64) NOT NULL,
    selected_answer_ids TEXT[] NOT NULL DEFAULT '{}',
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitQuestionAttemptsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initQuestionAttemptsTable)
	return err
}

const initQuestionAttemptsQuestionIndex = `
CREATE INDEX IF NOT EXISTS idx_question_attempts_question_id ON question_attempts (question_id)
`

func (q *Queries) InitQuestionAttemptsQuestionIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initQuestionAttemptsQuestionIndex)
	return err
}

const initQuestionAttemptsSpaceIndex = `
CREATE INDEX IF NOT EXISTS idx_question_attempts_space_id ON question_attempts (space_id)
`

func (q *Queries) InitQuestionAttemptsSpaceIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initQuestionAttemptsSpaceIndex)
	return err
}

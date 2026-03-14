package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// Question belongs to a SpaceItem and has a type, a body, and a list of Answers.
type Question struct {
	ID           string             `json:"id"`
	SpaceItemID  string             `json:"space_item_id"`
	QuestionType string             `json:"question_type"`
	Body         string             `json:"body"`
	CreatedBy    string             `json:"created_by"`
	UpdatedBy    string             `json:"updated_by"`
	CreatedTime  pgtype.Timestamptz `json:"created_time"`
	UpdatedTime  pgtype.Timestamptz `json:"updated_time"`
}

// Answer is one option/answer within a Question.
type Answer struct {
	ID          string             `json:"id"`
	QuestionID  string             `json:"question_id"`
	Text        string             `json:"text"`
	IsCorrect   bool               `json:"is_correct"`
	Position    int32              `json:"position"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

// ── Question param types ─────────────────────────────────────

type CreateQuestionParams struct {
	ID           string `json:"id"`
	SpaceItemID  string `json:"space_item_id"`
	QuestionType string `json:"question_type"`
	Body         string `json:"body"`
	CreatedBy    string `json:"created_by"`
	UpdatedBy    string `json:"updated_by"`
}

type UpdateQuestionParams struct {
	ID           string `json:"id"`
	QuestionType string `json:"question_type"`
	Body         string `json:"body"`
	UpdatedBy    string `json:"updated_by"`
}

// ── Answer param types ───────────────────────────────────────

type CreateAnswerParams struct {
	ID         string `json:"id"`
	QuestionID string `json:"question_id"`
	Text       string `json:"text"`
	IsCorrect  bool   `json:"is_correct"`
	Position   int32  `json:"position"`
	CreatedBy  string `json:"created_by"`
	UpdatedBy  string `json:"updated_by"`
}

type UpdateAnswerParams struct {
	ID        string `json:"id"`
	Text      string `json:"text"`
	IsCorrect bool   `json:"is_correct"`
	Position  int32  `json:"position"`
	UpdatedBy string `json:"updated_by"`
}

// ── Question queries ─────────────────────────────────────────

const createQuestion = `
INSERT INTO questions (id, space_item_id, question_type, body, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, space_item_id, question_type, body, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateQuestion(ctx context.Context, arg CreateQuestionParams) (Question, error) {
	row := q.db.QueryRow(ctx, createQuestion,
		arg.ID, arg.SpaceItemID, arg.QuestionType, arg.Body, arg.CreatedBy, arg.UpdatedBy)
	var qu Question
	err := row.Scan(&qu.ID, &qu.SpaceItemID, &qu.QuestionType, &qu.Body,
		&qu.CreatedBy, &qu.UpdatedBy, &qu.CreatedTime, &qu.UpdatedTime)
	return qu, err
}

const listQuestionsBySpaceItem = `
SELECT id, space_item_id, question_type, body, created_by, updated_by, created_time, updated_time
FROM questions WHERE space_item_id = $1 ORDER BY created_time ASC
`

func (q *Queries) ListQuestionsBySpaceItem(ctx context.Context, spaceItemID string) ([]Question, error) {
	rows, err := q.db.Query(ctx, listQuestionsBySpaceItem, spaceItemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var questions []Question
	for rows.Next() {
		var qu Question
		if err := rows.Scan(&qu.ID, &qu.SpaceItemID, &qu.QuestionType, &qu.Body,
			&qu.CreatedBy, &qu.UpdatedBy, &qu.CreatedTime, &qu.UpdatedTime); err != nil {
			return nil, err
		}
		questions = append(questions, qu)
	}
	return questions, rows.Err()
}

const getQuestionByID = `
SELECT id, space_item_id, question_type, body, created_by, updated_by, created_time, updated_time
FROM questions WHERE id = $1 LIMIT 1
`

func (q *Queries) GetQuestionByID(ctx context.Context, id string) (Question, error) {
	row := q.db.QueryRow(ctx, getQuestionByID, id)
	var qu Question
	err := row.Scan(&qu.ID, &qu.SpaceItemID, &qu.QuestionType, &qu.Body,
		&qu.CreatedBy, &qu.UpdatedBy, &qu.CreatedTime, &qu.UpdatedTime)
	return qu, err
}

const updateQuestion = `
UPDATE questions
SET question_type = $2, body = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, space_item_id, question_type, body, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateQuestion(ctx context.Context, arg UpdateQuestionParams) (Question, error) {
	row := q.db.QueryRow(ctx, updateQuestion, arg.ID, arg.QuestionType, arg.Body, arg.UpdatedBy)
	var qu Question
	err := row.Scan(&qu.ID, &qu.SpaceItemID, &qu.QuestionType, &qu.Body,
		&qu.CreatedBy, &qu.UpdatedBy, &qu.CreatedTime, &qu.UpdatedTime)
	return qu, err
}

const deleteQuestion = `DELETE FROM questions WHERE id = $1`

func (q *Queries) DeleteQuestion(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteQuestion, id)
	return err
}

const countQuestionsBySpaceItem = `SELECT COUNT(*) FROM questions WHERE space_item_id = $1`

func (q *Queries) CountQuestionsBySpaceItem(ctx context.Context, spaceItemID string) (int64, error) {
	var n int64
	err := q.db.QueryRow(ctx, countQuestionsBySpaceItem, spaceItemID).Scan(&n)
	return n, err
}

// ── Answer queries ───────────────────────────────────────────

const createAnswer = `
INSERT INTO answers (id, question_id, text, is_correct, position, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, question_id, text, is_correct, position, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateAnswer(ctx context.Context, arg CreateAnswerParams) (Answer, error) {
	row := q.db.QueryRow(ctx, createAnswer,
		arg.ID, arg.QuestionID, arg.Text, arg.IsCorrect, arg.Position, arg.CreatedBy, arg.UpdatedBy)
	var a Answer
	err := row.Scan(&a.ID, &a.QuestionID, &a.Text, &a.IsCorrect, &a.Position,
		&a.CreatedBy, &a.UpdatedBy, &a.CreatedTime, &a.UpdatedTime)
	return a, err
}

const listAnswersByQuestion = `
SELECT id, question_id, text, is_correct, position, created_by, updated_by, created_time, updated_time
FROM answers WHERE question_id = $1 ORDER BY position ASC, created_time ASC
`

func (q *Queries) ListAnswersByQuestion(ctx context.Context, questionID string) ([]Answer, error) {
	rows, err := q.db.Query(ctx, listAnswersByQuestion, questionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var answers []Answer
	for rows.Next() {
		var a Answer
		if err := rows.Scan(&a.ID, &a.QuestionID, &a.Text, &a.IsCorrect, &a.Position,
			&a.CreatedBy, &a.UpdatedBy, &a.CreatedTime, &a.UpdatedTime); err != nil {
			return nil, err
		}
		answers = append(answers, a)
	}
	return answers, rows.Err()
}

const getAnswerByID = `
SELECT id, question_id, text, is_correct, position, created_by, updated_by, created_time, updated_time
FROM answers WHERE id = $1 LIMIT 1
`

func (q *Queries) GetAnswerByID(ctx context.Context, id string) (Answer, error) {
	row := q.db.QueryRow(ctx, getAnswerByID, id)
	var a Answer
	err := row.Scan(&a.ID, &a.QuestionID, &a.Text, &a.IsCorrect, &a.Position,
		&a.CreatedBy, &a.UpdatedBy, &a.CreatedTime, &a.UpdatedTime)
	return a, err
}

const updateAnswer = `
UPDATE answers
SET text = $2, is_correct = $3, position = $4, updated_by = $5, updated_time = NOW()
WHERE id = $1
RETURNING id, question_id, text, is_correct, position, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateAnswer(ctx context.Context, arg UpdateAnswerParams) (Answer, error) {
	row := q.db.QueryRow(ctx, updateAnswer, arg.ID, arg.Text, arg.IsCorrect, arg.Position, arg.UpdatedBy)
	var a Answer
	err := row.Scan(&a.ID, &a.QuestionID, &a.Text, &a.IsCorrect, &a.Position,
		&a.CreatedBy, &a.UpdatedBy, &a.CreatedTime, &a.UpdatedTime)
	return a, err
}

const deleteAnswer = `DELETE FROM answers WHERE id = $1`

func (q *Queries) DeleteAnswer(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteAnswer, id)
	return err
}

const countAnswersByQuestion = `SELECT COUNT(*) FROM answers WHERE question_id = $1`

func (q *Queries) CountAnswersByQuestion(ctx context.Context, questionID string) (int64, error) {
	var n int64
	err := q.db.QueryRow(ctx, countAnswersByQuestion, questionID).Scan(&n)
	return n, err
}

// ── Init queries ─────────────────────────────────────────────

const initQuestionsTable = `
CREATE TABLE IF NOT EXISTS questions (
    id VARCHAR(64) PRIMARY KEY,
    space_item_id VARCHAR(64) NOT NULL REFERENCES space_items(id) ON DELETE CASCADE,
    question_type VARCHAR(50) NOT NULL DEFAULT '',
    body TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitQuestionsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initQuestionsTable)
	return err
}

const initQuestionsSpaceItemIndex = `CREATE INDEX IF NOT EXISTS idx_questions_space_item_id ON questions (space_item_id)`

func (q *Queries) InitQuestionsSpaceItemIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initQuestionsSpaceItemIndex)
	return err
}

const initAnswersTable = `
CREATE TABLE IF NOT EXISTS answers (
    id VARCHAR(64) PRIMARY KEY,
    question_id VARCHAR(64) NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    text TEXT NOT NULL DEFAULT '',
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    position INT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitAnswersTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initAnswersTable)
	return err
}

const initAnswersQuestionIndex = `CREATE INDEX IF NOT EXISTS idx_answers_question_id ON answers (question_id)`

func (q *Queries) InitAnswersQuestionIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initAnswersQuestionIndex)
	return err
}

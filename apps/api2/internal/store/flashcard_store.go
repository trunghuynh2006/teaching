package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// FlashCard belongs to a Space and has a front (prompt) and back (answer).
// SR fields implement the SM-2 spaced-repetition schedule.
type FlashCard struct {
	ID           string             `json:"id"`
	SpaceID      string             `json:"space_id"`
	Front        string             `json:"front"`
	Back         string             `json:"back"`
	DueAt        pgtype.Timestamptz `json:"due_at"`
	IntervalDays int32              `json:"interval_days"`
	EaseFactor   float64            `json:"ease_factor"`
	ReviewCount  int32              `json:"review_count"`
	CreatedBy    string             `json:"created_by"`
	UpdatedBy    string             `json:"updated_by"`
	CreatedTime  pgtype.Timestamptz `json:"created_time"`
	UpdatedTime  pgtype.Timestamptz `json:"updated_time"`
}

// ── Param types ───────────────────────────────────────────────

type CreateFlashCardParams struct {
	ID        string `json:"id"`
	SpaceID   string `json:"space_id"`
	Front     string `json:"front"`
	Back      string `json:"back"`
	CreatedBy string `json:"created_by"`
	UpdatedBy string `json:"updated_by"`
}

type UpdateFlashCardParams struct {
	ID        string `json:"id"`
	Front     string `json:"front"`
	Back      string `json:"back"`
	UpdatedBy string `json:"updated_by"`
}

type ReviewFlashCardParams struct {
	ID           string             `json:"id"`
	EaseFactor   float64            `json:"ease_factor"`
	IntervalDays int32              `json:"interval_days"`
	ReviewCount  int32              `json:"review_count"`
	DueAt        pgtype.Timestamptz `json:"due_at"`
	UpdatedBy    string             `json:"updated_by"`
}

// ── Queries ───────────────────────────────────────────────────

const createFlashCard = `
INSERT INTO flash_cards (id, space_id, front, back, due_at, interval_days, ease_factor, review_count, created_by, updated_by)
VALUES ($1, $2, $3, $4, NOW(), 1, 2.5, 0, $5, $6)
RETURNING id, space_id, front, back, due_at, interval_days, ease_factor, review_count, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateFlashCard(ctx context.Context, arg CreateFlashCardParams) (FlashCard, error) {
	row := q.db.QueryRow(ctx, createFlashCard,
		arg.ID, arg.SpaceID, arg.Front, arg.Back, arg.CreatedBy, arg.UpdatedBy)
	var c FlashCard
	err := row.Scan(&c.ID, &c.SpaceID, &c.Front, &c.Back,
		&c.DueAt, &c.IntervalDays, &c.EaseFactor, &c.ReviewCount,
		&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const listFlashCardsBySpace = `
SELECT id, space_id, front, back, due_at, interval_days, ease_factor, review_count, created_by, updated_by, created_time, updated_time
FROM flash_cards WHERE space_id = $1 ORDER BY created_time ASC
`

func (q *Queries) ListFlashCardsBySpace(ctx context.Context, spaceID string) ([]FlashCard, error) {
	rows, err := q.db.Query(ctx, listFlashCardsBySpace, spaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var cards []FlashCard
	for rows.Next() {
		var c FlashCard
		if err := rows.Scan(&c.ID, &c.SpaceID, &c.Front, &c.Back,
			&c.DueAt, &c.IntervalDays, &c.EaseFactor, &c.ReviewCount,
			&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime); err != nil {
			return nil, err
		}
		cards = append(cards, c)
	}
	return cards, rows.Err()
}

const listFlashCardsDueBySpace = `
SELECT id, space_id, front, back, due_at, interval_days, ease_factor, review_count, created_by, updated_by, created_time, updated_time
FROM flash_cards
WHERE space_id = $1 AND (due_at IS NULL OR due_at <= NOW())
ORDER BY due_at ASC NULLS FIRST
`

func (q *Queries) ListFlashCardsDueBySpace(ctx context.Context, spaceID string) ([]FlashCard, error) {
	rows, err := q.db.Query(ctx, listFlashCardsDueBySpace, spaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var cards []FlashCard
	for rows.Next() {
		var c FlashCard
		if err := rows.Scan(&c.ID, &c.SpaceID, &c.Front, &c.Back,
			&c.DueAt, &c.IntervalDays, &c.EaseFactor, &c.ReviewCount,
			&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime); err != nil {
			return nil, err
		}
		cards = append(cards, c)
	}
	return cards, rows.Err()
}

const getFlashCardByID = `
SELECT id, space_id, front, back, due_at, interval_days, ease_factor, review_count, created_by, updated_by, created_time, updated_time
FROM flash_cards WHERE id = $1 LIMIT 1
`

func (q *Queries) GetFlashCardByID(ctx context.Context, id string) (FlashCard, error) {
	row := q.db.QueryRow(ctx, getFlashCardByID, id)
	var c FlashCard
	err := row.Scan(&c.ID, &c.SpaceID, &c.Front, &c.Back,
		&c.DueAt, &c.IntervalDays, &c.EaseFactor, &c.ReviewCount,
		&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const updateFlashCard = `
UPDATE flash_cards
SET front = $2, back = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, space_id, front, back, due_at, interval_days, ease_factor, review_count, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateFlashCard(ctx context.Context, arg UpdateFlashCardParams) (FlashCard, error) {
	row := q.db.QueryRow(ctx, updateFlashCard, arg.ID, arg.Front, arg.Back, arg.UpdatedBy)
	var c FlashCard
	err := row.Scan(&c.ID, &c.SpaceID, &c.Front, &c.Back,
		&c.DueAt, &c.IntervalDays, &c.EaseFactor, &c.ReviewCount,
		&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const reviewFlashCard = `
UPDATE flash_cards
SET ease_factor = $2, interval_days = $3, review_count = $4, due_at = $5, updated_by = $6, updated_time = NOW()
WHERE id = $1
RETURNING id, space_id, front, back, due_at, interval_days, ease_factor, review_count, created_by, updated_by, created_time, updated_time
`

func (q *Queries) ReviewFlashCard(ctx context.Context, arg ReviewFlashCardParams) (FlashCard, error) {
	row := q.db.QueryRow(ctx, reviewFlashCard,
		arg.ID, arg.EaseFactor, arg.IntervalDays, arg.ReviewCount, arg.DueAt, arg.UpdatedBy)
	var c FlashCard
	err := row.Scan(&c.ID, &c.SpaceID, &c.Front, &c.Back,
		&c.DueAt, &c.IntervalDays, &c.EaseFactor, &c.ReviewCount,
		&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const deleteFlashCard = `DELETE FROM flash_cards WHERE id = $1`

func (q *Queries) DeleteFlashCard(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteFlashCard, id)
	return err
}

// ── Init / Migrate ─────────────────────────────────────────────

const initFlashCardsTable = `
CREATE TABLE IF NOT EXISTS flash_cards (
    id VARCHAR(64) PRIMARY KEY,
    space_id VARCHAR(64) NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    front TEXT NOT NULL DEFAULT '',
    back TEXT NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL,
    updated_by VARCHAR(64) NOT NULL,
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitFlashCardsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initFlashCardsTable)
	return err
}

const initFlashCardsSpaceIndex = `CREATE INDEX IF NOT EXISTS idx_flash_cards_space_id ON flash_cards (space_id)`

func (q *Queries) InitFlashCardsSpaceIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initFlashCardsSpaceIndex)
	return err
}

const migrateFlashCardsSRColumns = `
ALTER TABLE flash_cards
    ADD COLUMN IF NOT EXISTS due_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS interval_days INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS ease_factor FLOAT8 NOT NULL DEFAULT 2.5,
    ADD COLUMN IF NOT EXISTS review_count INT NOT NULL DEFAULT 0
`

func (q *Queries) MigrateFlashCardsSRColumns(ctx context.Context) error {
	_, err := q.db.Exec(ctx, migrateFlashCardsSRColumns)
	return err
}

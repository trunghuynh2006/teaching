package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// FlashCard belongs to a SpaceItem and has a front (prompt) and back (answer).
type FlashCard struct {
	ID          string             `json:"id"`
	SpaceItemID string             `json:"space_item_id"`
	Front       string             `json:"front"`
	Back        string             `json:"back"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

// ── Param types ───────────────────────────────────────────────

type CreateFlashCardParams struct {
	ID          string `json:"id"`
	SpaceItemID string `json:"space_item_id"`
	Front       string `json:"front"`
	Back        string `json:"back"`
	CreatedBy   string `json:"created_by"`
	UpdatedBy   string `json:"updated_by"`
}

type UpdateFlashCardParams struct {
	ID        string `json:"id"`
	Front     string `json:"front"`
	Back      string `json:"back"`
	UpdatedBy string `json:"updated_by"`
}

// ── Queries ───────────────────────────────────────────────────

const createFlashCard = `
INSERT INTO flash_cards (id, space_item_id, front, back, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, space_item_id, front, back, created_by, updated_by, created_time, updated_time
`

func (q *Queries) CreateFlashCard(ctx context.Context, arg CreateFlashCardParams) (FlashCard, error) {
	row := q.db.QueryRow(ctx, createFlashCard,
		arg.ID, arg.SpaceItemID, arg.Front, arg.Back, arg.CreatedBy, arg.UpdatedBy)
	var c FlashCard
	err := row.Scan(&c.ID, &c.SpaceItemID, &c.Front, &c.Back,
		&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const listFlashCardsBySpaceItem = `
SELECT id, space_item_id, front, back, created_by, updated_by, created_time, updated_time
FROM flash_cards WHERE space_item_id = $1 ORDER BY created_time ASC
`

func (q *Queries) ListFlashCardsBySpaceItem(ctx context.Context, spaceItemID string) ([]FlashCard, error) {
	rows, err := q.db.Query(ctx, listFlashCardsBySpaceItem, spaceItemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var cards []FlashCard
	for rows.Next() {
		var c FlashCard
		if err := rows.Scan(&c.ID, &c.SpaceItemID, &c.Front, &c.Back,
			&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime); err != nil {
			return nil, err
		}
		cards = append(cards, c)
	}
	return cards, rows.Err()
}

const getFlashCardByID = `
SELECT id, space_item_id, front, back, created_by, updated_by, created_time, updated_time
FROM flash_cards WHERE id = $1 LIMIT 1
`

func (q *Queries) GetFlashCardByID(ctx context.Context, id string) (FlashCard, error) {
	row := q.db.QueryRow(ctx, getFlashCardByID, id)
	var c FlashCard
	err := row.Scan(&c.ID, &c.SpaceItemID, &c.Front, &c.Back,
		&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const updateFlashCard = `
UPDATE flash_cards
SET front = $2, back = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING id, space_item_id, front, back, created_by, updated_by, created_time, updated_time
`

func (q *Queries) UpdateFlashCard(ctx context.Context, arg UpdateFlashCardParams) (FlashCard, error) {
	row := q.db.QueryRow(ctx, updateFlashCard, arg.ID, arg.Front, arg.Back, arg.UpdatedBy)
	var c FlashCard
	err := row.Scan(&c.ID, &c.SpaceItemID, &c.Front, &c.Back,
		&c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const deleteFlashCard = `DELETE FROM flash_cards WHERE id = $1`

func (q *Queries) DeleteFlashCard(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteFlashCard, id)
	return err
}

// ── Init ──────────────────────────────────────────────────────

const initFlashCardsTable = `
CREATE TABLE IF NOT EXISTS flash_cards (
    id VARCHAR(64) PRIMARY KEY,
    space_item_id VARCHAR(64) NOT NULL REFERENCES space_items(id) ON DELETE CASCADE,
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

const initFlashCardsSpaceItemIndex = `CREATE INDEX IF NOT EXISTS idx_flash_cards_space_item_id ON flash_cards (space_item_id)`

func (q *Queries) InitFlashCardsSpaceItemIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initFlashCardsSpaceItemIndex)
	return err
}

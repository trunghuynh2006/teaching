package httpapi

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"api2/internal/domain/user"
	"api2/internal/store"

	"github.com/jackc/pgx/v5/pgtype"
)

type BulkSaveAnkiCardsRequest struct {
	Cards []struct {
		FrontText  string   `json:"front_text"`
		BackText   string   `json:"back_text"`
		BloomLevel string   `json:"bloom_level"`
		Tags       []string `json:"tags"`
	} `json:"cards"`
}

// BulkSaveAnkiCards handles POST /anki/cards/bulk.
// Saves a batch of approved generated cards for the current user.
func (h *Handler) BulkSaveAnkiCards(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	var payload BulkSaveAnkiCardsRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "invalid request body"})
		return
	}
	if len(payload.Cards) == 0 {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "no cards provided"})
		return
	}

	saved := make([]store.AnkiCard, 0, len(payload.Cards))
	for _, c := range payload.Cards {
		tags := c.Tags
		if tags == nil {
			tags = []string{}
		}
		username := currentUser.Username

		card, err := h.Queries.CreateAnkiCard(r.Context(), store.CreateAnkiCardParams{
			ID:         newID(),
			UserID:     fmt.Sprintf("%d", currentUser.ID),
			FrontText:  c.FrontText,
			BackText:   c.BackText,
			BloomLevel: pgtype.Text{String: c.BloomLevel, Valid: c.BloomLevel != ""},
			Tags:       tags,
			CreatedBy:  pgtype.Text{String: username, Valid: true},
			UpdatedBy:  pgtype.Text{String: username, Valid: true},
		})
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to save cards"})
			return
		}
		saved = append(saved, card)
	}

	writeJSON(w, http.StatusCreated, map[string]any{"cards": saved, "count": len(saved)})
}

func newID() string {
	const chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	b := make([]byte, 16)
	for i := range b {
		b[i] = chars[r.Intn(len(chars))]
	}
	return string(b)
}

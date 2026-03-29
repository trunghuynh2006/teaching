package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"api2/internal/domain/user"
	infra_ai "api2/internal/infra/ai"

	"github.com/jackc/pgx/v5"
)

// GenerateAnkiCardsForSpace handles POST /spaces/{id}/generate-anki-cards.
// It generates Anki cards from a knowledge source using the AI service,
// marks the source as anki_generated, and returns the generated cards.
func (h *Handler) GenerateAnkiCardsForSpace(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	spaceID := strings.TrimSpace(r.PathValue("id"))
	if spaceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
		return
	}

	var body struct {
		SourceID string `json:"source_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid request body"})
		return
	}
	if strings.TrimSpace(body.SourceID) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "source_id is required"})
		return
	}

	// Verify space exists
	if _, err := h.Queries.GetSpaceByID(r.Context(), spaceID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Space not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	src, err := h.Queries.GetSourceByID(r.Context(), body.SourceID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Source not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	if h.AIClient == nil {
		writeJSON(w, http.StatusServiceUnavailable, ErrorResponse{Detail: "AI service not configured"})
		return
	}

	serviceToken, err := h.AuthService.Tokens.CreateAccessToken("api2-service", "teacher")
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	cards, err := h.AIClient.GenerateAnkiCards(ctx, serviceToken, infra_ai.GenerateAnkiCardsRequest{
		SourceText: src.Content,
		Language:   "English",
	})
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}

	// Mark source as anki_generated regardless of whether user saves any cards
	_ = h.Queries.MarkSourceAnkiGenerated(r.Context(), src.ID)

	// Return generated cards — frontend handles review + save via flash-cards endpoint
	type generatedCard struct {
		FrontText  string   `json:"front_text"`
		BackText   string   `json:"back_text"`
		BloomLevel string   `json:"bloom_level"`
		Tags       []string `json:"tags,omitempty"`
	}
	out := make([]generatedCard, 0, len(cards))
	for _, c := range cards {
		tags := c.Tags
		if tags == nil {
			tags = []string{}
		}
		out = append(out, generatedCard{
			FrontText:  c.FrontText,
			BackText:   c.BackText,
			BloomLevel: c.BloomLevel,
			Tags:       tags,
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{"cards": out, "source_id": src.ID})
}

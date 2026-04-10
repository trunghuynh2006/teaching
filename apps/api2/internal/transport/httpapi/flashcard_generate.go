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
	"api2/internal/store"

	"github.com/jackc/pgx/v5"
)

// GenerateFlashCardsForSpace handles POST /spaces/{id}/generate-flash-cards.
// Accepts a list of concept names, calls the AI service, persists and returns the cards.
func (h *Handler) GenerateFlashCardsForSpace(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	spaceID := strings.TrimSpace(r.PathValue("id"))
	if spaceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
		return
	}

	var body struct {
		Concepts []string `json:"concepts"`
		Domain   string   `json:"domain"`
		Language string   `json:"language"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid request body"})
		return
	}

	var concepts []string
	for _, c := range body.Concepts {
		if t := strings.TrimSpace(c); t != "" {
			concepts = append(concepts, t)
		}
	}
	if len(concepts) == 0 {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "at least one concept is required"})
		return
	}

	if _, err := h.Queries.GetSpaceByID(r.Context(), spaceID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Space not found"})
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

	ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
	defer cancel()

	generated, err := h.AIClient.GenerateFlashCards(ctx, serviceToken, infra_ai.GenerateFlashCardsRequest{
		Concepts: concepts,
		Domain:   strings.TrimSpace(body.Domain),
		Language: body.Language,
	})
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}

	type savedCard struct {
		ID    string `json:"id"`
		Front string `json:"front"`
		Back  string `json:"back"`
	}

	out := make([]savedCard, 0, len(generated))
	for _, gc := range generated {
		row, saveErr := h.Queries.CreateFlashCard(r.Context(), store.CreateFlashCardParams{
			ID:        newFlashCardID(),
			SpaceID:   spaceID,
			Front:     gc.FrontText,
			Back:      gc.BackText,
			CreatedBy: currentUser.Username,
			UpdatedBy: currentUser.Username,
		})
		if saveErr != nil {
			continue
		}
		out = append(out, savedCard{ID: row.ID, Front: row.Front, Back: row.Back})
	}

	writeJSON(w, http.StatusCreated, map[string]any{"flashcards": out})
}

package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"

	infra_ai "api2/internal/infra/ai"
	"api2/internal/domain/user"
)

// GenerateAnkiCards handles POST /ai/anki-cards.
// It proxies the request to the ai service and returns the generated cards.
func (h *Handler) GenerateAnkiCards(w http.ResponseWriter, r *http.Request, _ user.User) {
	var payload infra_ai.GenerateAnkiCardsRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "invalid request body"})
		return
	}

	bearerToken := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")

	cards, err := h.AIClient.GenerateAnkiCards(r.Context(), bearerToken, payload)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"cards": cards})
}

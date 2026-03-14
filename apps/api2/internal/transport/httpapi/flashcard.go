package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"api2/internal/domain/user"
	"api2/internal/sharedmodels"
	"api2/internal/store"

	"github.com/jackc/pgx/v5"
)

// ── FlashCard handlers ────────────────────────────────────────

func (h *Handler) ListSpaceItemFlashCards(w http.ResponseWriter, r *http.Request, _ user.User) {
	spaceItemID := strings.TrimSpace(r.PathValue("id"))
	if spaceItemID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space item id is required"})
		return
	}
	if _, err := h.Queries.GetSpaceItemByID(r.Context(), spaceItemID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Space item not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	rows, err := h.Queries.ListFlashCardsBySpaceItem(r.Context(), spaceItemID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.FlashCard, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedFlashCard(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetFlashCard(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Flash card id is required"})
		return
	}
	row, err := h.Queries.GetFlashCardByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Flash card not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedFlashCard(row))
}

func (h *Handler) CreateFlashCard(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	spaceItemID := strings.TrimSpace(r.PathValue("id"))
	if spaceItemID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space item id is required"})
		return
	}
	if _, err := h.Queries.GetSpaceItemByID(r.Context(), spaceItemID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Space item not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	input, err := decodeFlashCardInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.CreateFlashCard(r.Context(), store.CreateFlashCardParams{
		ID:          newFlashCardID(),
		SpaceItemID: spaceItemID,
		Front:       input.Front,
		Back:        input.Back,
		CreatedBy:   currentUser.Username,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedFlashCard(row))
}

func (h *Handler) UpdateFlashCard(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Flash card id is required"})
		return
	}
	input, err := decodeFlashCardInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateFlashCard(r.Context(), store.UpdateFlashCardParams{
		ID:        id,
		Front:     input.Front,
		Back:      input.Back,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Flash card not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedFlashCard(row))
}

func (h *Handler) DeleteFlashCard(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Flash card id is required"})
		return
	}
	if err := h.Queries.DeleteFlashCard(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Helpers ───────────────────────────────────────────────────

type flashCardInput struct {
	Front string
	Back  string
}

func decodeFlashCardInput(r *http.Request) (flashCardInput, error) {
	var payload struct {
		Front string `json:"front"`
		Back  string `json:"back"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return flashCardInput{}, errors.New("Invalid request body")
	}
	front := strings.TrimSpace(payload.Front)
	if front == "" {
		return flashCardInput{}, errors.New("Front is required")
	}
	return flashCardInput{Front: front, Back: strings.TrimSpace(payload.Back)}, nil
}

func newFlashCardID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "fc_" + time.Now().UTC().Format("20060102150405")
	}
	return "fc_" + hex.EncodeToString(b[:])
}

func toSharedFlashCard(c store.FlashCard) sharedmodels.FlashCard {
	out := sharedmodels.FlashCard{
		Id:          c.ID,
		SpaceItemId: c.SpaceItemID,
		Front:       c.Front,
		Back:        c.Back,
		CreatedBy:   &c.CreatedBy,
		UpdatedBy:   &c.UpdatedBy,
	}
	if c.CreatedTime.Valid {
		ts := c.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if c.UpdatedTime.Valid {
		ts := c.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

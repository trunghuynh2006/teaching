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
	"github.com/jackc/pgx/v5/pgtype"
)

// ── FlashCard handlers ────────────────────────────────────────

func (h *Handler) ListSpaceFlashCards(w http.ResponseWriter, r *http.Request, _ user.User) {
	spaceID := strings.TrimSpace(r.PathValue("id"))
	if spaceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
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
	rows, err := h.Queries.ListFlashCardsBySpace(r.Context(), spaceID)
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

// ListSpaceFlashCardsDue handles GET /spaces/{id}/flash-cards/due.
// Returns cards whose due_at <= NOW() ordered by due_at ascending.
func (h *Handler) ListSpaceFlashCardsDue(w http.ResponseWriter, r *http.Request, _ user.User) {
	spaceID := strings.TrimSpace(r.PathValue("id"))
	if spaceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
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
	rows, err := h.Queries.ListFlashCardsDueBySpace(r.Context(), spaceID)
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
	spaceID := strings.TrimSpace(r.PathValue("id"))
	if spaceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
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
	input, err := decodeFlashCardInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.CreateFlashCard(r.Context(), store.CreateFlashCardParams{
		ID:        newFlashCardID(),
		SpaceID:   spaceID,
		Front:     input.Front,
		Back:      input.Back,
		CreatedBy: currentUser.Username,
		UpdatedBy: currentUser.Username,
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

// ReviewFlashCard handles POST /flash-cards/{id}/review.
// Applies SM-2 and schedules the next review.
func (h *Handler) ReviewFlashCard(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Flash card id is required"})
		return
	}

	var payload struct {
		Rating ReviewRating `json:"rating"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid request body"})
		return
	}
	switch payload.Rating {
	case RatingAgain, RatingHard, RatingGood, RatingEasy:
	default:
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "rating must be again, hard, good, or easy"})
		return
	}

	card, err := h.Queries.GetFlashCardByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Flash card not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	newEase, newInterval, newReps, _ := applyReview(
		payload.Rating,
		card.EaseFactor,
		int(card.IntervalDays),
		int(card.ReviewCount),
		0,
	)

	dueAt := time.Now().UTC().Add(time.Duration(newInterval) * 24 * time.Hour)

	updated, err := h.Queries.ReviewFlashCard(r.Context(), store.ReviewFlashCardParams{
		ID:           id,
		EaseFactor:   newEase,
		IntervalDays: int32(newInterval),
		ReviewCount:  int32(newReps),
		DueAt:        pgtype.Timestamptz{Time: dueAt, Valid: true},
		UpdatedBy:    currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedFlashCard(updated))
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
	intervalDays := int(c.IntervalDays)
	reviewCount := int(c.ReviewCount)
	out := sharedmodels.FlashCard{
		Id:           c.ID,
		SpaceId:      c.SpaceID,
		Front:        c.Front,
		Back:         c.Back,
		IntervalDays: &intervalDays,
		EaseFactor:   &c.EaseFactor,
		ReviewCount:  &reviewCount,
		CreatedBy:    &c.CreatedBy,
		UpdatedBy:    &c.UpdatedBy,
	}
	if c.DueAt.Valid {
		ts := c.DueAt.Time.UTC().Format(time.RFC3339)
		out.DueAt = &ts
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

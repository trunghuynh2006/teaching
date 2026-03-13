package httpapi

import (
	"encoding/json"
	"fmt"
	"math"
	"math/big"
	"net/http"
	"time"

	"api2/internal/domain/user"
	"api2/internal/store"

	"github.com/jackc/pgx/v5/pgtype"
)

// ListAnkiCardsDue handles GET /anki/cards/due.
func (h *Handler) ListAnkiCardsDue(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	userID := fmt.Sprintf("%d", currentUser.ID)
	cards, err := h.Queries.ListAnkiCardsDue(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to fetch cards"})
		return
	}
	if cards == nil {
		cards = []store.AnkiCard{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"cards": cards, "count": len(cards)})
}

// ReviewRating is the user's self-assessed difficulty for a card.
type ReviewRating string

const (
	RatingAgain ReviewRating = "again"
	RatingHard  ReviewRating = "hard"
	RatingGood  ReviewRating = "good"
	RatingEasy  ReviewRating = "easy"
)

type ReviewAnkiCardRequest struct {
	Rating ReviewRating `json:"rating"`
}

// ReviewAnkiCard handles POST /anki/cards/{id}/review.
// Applies the SM-2 spaced-repetition algorithm and schedules the next review.
func (h *Handler) ReviewAnkiCard(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	cardID := r.PathValue("id")
	if cardID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "missing card id"})
		return
	}

	var payload ReviewAnkiCardRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "invalid request body"})
		return
	}

	switch payload.Rating {
	case RatingAgain, RatingHard, RatingGood, RatingEasy:
	default:
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "rating must be again, hard, good, or easy"})
		return
	}

	userID := fmt.Sprintf("%d", currentUser.ID)
	card, err := h.Queries.GetAnkiCardByID(r.Context(), store.GetAnkiCardByIDParams{
		ID:     cardID,
		UserID: userID,
	})
	if err != nil {
		writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "card not found"})
		return
	}

	currentEase := numericToFloat64(card.EaseFactor)
	newEase, newInterval, newReps, newLapses := applyReview(
		payload.Rating,
		currentEase,
		int(card.IntervalDays),
		int(card.Repetitions),
		int(card.Lapses),
	)

	var ef pgtype.Numeric
	_ = ef.Scan(fmt.Sprintf("%.4f", newEase))

	dueAt := time.Now().UTC().Add(time.Duration(newInterval) * 24 * time.Hour)

	updated, err := h.Queries.ReviewAnkiCard(r.Context(), store.ReviewAnkiCardParams{
		ID:           cardID,
		UserID:       userID,
		EaseFactor:   ef,
		IntervalDays: int32(newInterval),
		Repetitions:  int32(newReps),
		Lapses:       int32(newLapses),
		DueAt:        pgtype.Timestamptz{Time: dueAt, Valid: true},
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to update card"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"card": updated})
}

func numericToFloat64(n pgtype.Numeric) float64 {
	if !n.Valid || n.Int == nil {
		return 2.5
	}
	f, _ := new(big.Float).SetInt(n.Int).Float64()
	if n.Exp != 0 {
		f *= math.Pow10(int(n.Exp))
	}
	return f
}

// applyReview runs the SM-2 algorithm.
// Returns (newEaseFactor, newIntervalDays, newRepetitions, newLapses).
func applyReview(rating ReviewRating, ease float64, interval, repetitions, lapses int) (float64, int, int, int) {
	const minEase = 1.3

	switch rating {
	case RatingAgain:
		ease = math.Max(minEase, ease-0.2)
		return ease, 1, 0, lapses + 1

	case RatingHard:
		ease = math.Max(minEase, ease-0.15)
		newInterval := int(math.Max(1, math.Round(float64(interval)*1.2)))
		return ease, newInterval, repetitions, lapses

	case RatingGood:
		var newInterval int
		switch repetitions {
		case 0:
			newInterval = 1
		case 1:
			newInterval = 4
		default:
			newInterval = int(math.Round(float64(interval) * ease))
		}
		if newInterval < 1 {
			newInterval = 1
		}
		return ease, newInterval, repetitions + 1, lapses

	case RatingEasy:
		var newInterval int
		if repetitions == 0 {
			newInterval = 4
		} else {
			newInterval = int(math.Round(float64(interval) * ease * 1.3))
		}
		if newInterval < 1 {
			newInterval = 1
		}
		ease += 0.15
		return ease, newInterval, repetitions + 1, lapses
	}

	return ease, interval, repetitions, lapses
}

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
	"api2/internal/store"

	"github.com/jackc/pgx/v5"
)

// RecordQuestionAttempt handles POST /questions/{id}/attempt.
// The client sends the answer IDs the user selected; the server evaluates
// correctness, persists the attempt, and returns the result plus running stats.
func (h *Handler) RecordQuestionAttempt(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	questionID := strings.TrimSpace(r.PathValue("id"))
	if questionID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Question id is required"})
		return
	}

	var body struct {
		SelectedAnswerIDs []string `json:"selected_answer_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid request body"})
		return
	}

	q, err := h.Queries.GetQuestionByID(r.Context(), questionID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Question not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	// Evaluate correctness: selected set must exactly match correct answer set.
	answers, err := h.Queries.ListAnswersByQuestion(r.Context(), questionID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	correctSet := make(map[string]struct{})
	for _, a := range answers {
		if a.IsCorrect {
			correctSet[a.ID] = struct{}{}
		}
	}
	selectedSet := make(map[string]struct{}, len(body.SelectedAnswerIDs))
	for _, id := range body.SelectedAnswerIDs {
		selectedSet[id] = struct{}{}
	}
	isCorrect := len(correctSet) == len(selectedSet)
	if isCorrect {
		for id := range correctSet {
			if _, ok := selectedSet[id]; !ok {
				isCorrect = false
				break
			}
		}
	}

	attempt, err := h.Queries.CreateQuestionAttempt(r.Context(), store.CreateQuestionAttemptParams{
		ID:                newAttemptID(),
		QuestionID:        questionID,
		SpaceID:           q.SpaceID,
		Username:          currentUser.Username,
		SelectedAnswerIDs: body.SelectedAnswerIDs,
		IsCorrect:         isCorrect,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	answeredAt := ""
	if attempt.AnsweredAt.Valid {
		answeredAt = attempt.AnsweredAt.Time.UTC().Format(time.RFC3339)
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"id":                  attempt.ID,
		"question_id":         attempt.QuestionID,
		"space_id":            attempt.SpaceID,
		"is_correct":          attempt.IsCorrect,
		"selected_answer_ids": attempt.SelectedAnswerIDs,
		"answered_at":         answeredAt,
	})
}

// ListSpaceAttemptStats handles GET /spaces/{id}/attempts/stats.
// Returns per-question attempt counts for the space, useful for teacher dashboards.
func (h *Handler) ListSpaceAttemptStats(w http.ResponseWriter, r *http.Request, _ user.User) {
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
	stats, err := h.Queries.GetSpaceAttemptStats(r.Context(), spaceID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"stats": stats})
}

// ListMySpaceAttempts handles GET /spaces/{id}/my-attempts.
// Returns all attempts by the current user in the space, ordered newest first.
func (h *Handler) ListMySpaceAttempts(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	spaceID := strings.TrimSpace(r.PathValue("id"))
	if spaceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
		return
	}
	attempts, err := h.Queries.ListMySpaceAttempts(r.Context(), spaceID, currentUser.Username)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	type attemptItem struct {
		ID                string   `json:"id"`
		QuestionID        string   `json:"question_id"`
		SelectedAnswerIDs []string `json:"selected_answer_ids"`
		IsCorrect         bool     `json:"is_correct"`
		AnsweredAt        string   `json:"answered_at"`
	}
	out := make([]attemptItem, 0, len(attempts))
	for _, a := range attempts {
		ts := ""
		if a.AnsweredAt.Valid {
			ts = a.AnsweredAt.Time.UTC().Format(time.RFC3339)
		}
		out = append(out, attemptItem{
			ID:                a.ID,
			QuestionID:        a.QuestionID,
			SelectedAnswerIDs: a.SelectedAnswerIDs,
			IsCorrect:         a.IsCorrect,
			AnsweredAt:        ts,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"attempts": out})
}

func newAttemptID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "att_" + time.Now().UTC().Format("20060102150405")
	}
	return "att_" + hex.EncodeToString(b[:])
}

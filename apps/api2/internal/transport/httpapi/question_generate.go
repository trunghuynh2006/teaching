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

// GenerateQuestionsForSpace handles POST /spaces/{id}/generate-questions.
// It generates multiple-choice questions from a knowledge source via the AI service,
// persists the question + answers, and returns them.
func (h *Handler) GenerateQuestionsForSpace(w http.ResponseWriter, r *http.Request, currentUser user.User) {
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

	ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
	defer cancel()

	generated, err := h.AIClient.GenerateMCQuestions(ctx, serviceToken, infra_ai.GenerateMCQuestionsRequest{
		SourceText: src.Content,
		Language:   "English",
	})
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}

	type savedAnswer struct {
		ID        string `json:"id"`
		Text      string `json:"text"`
		IsCorrect bool   `json:"is_correct"`
		Position  int    `json:"position"`
	}
	type savedQuestion struct {
		ID           string        `json:"id"`
		QuestionType string        `json:"question_type"`
		Body         string        `json:"body"`
		Answers      []savedAnswer `json:"answers"`
	}

	out := make([]savedQuestion, 0, len(generated))
	for _, gq := range generated {
		qRow, qErr := h.Queries.CreateQuestion(r.Context(), store.CreateQuestionParams{
			ID:           newQuestionID(),
			SpaceID:      spaceID,
			QuestionType: "multiple_choice",
			Body:         gq.Body,
			CreatedBy:    currentUser.Username,
			UpdatedBy:    currentUser.Username,
		})
		if qErr != nil {
			continue
		}

		answers := make([]savedAnswer, 0, len(gq.Answers))
		for i, ga := range gq.Answers {
			aRow, aErr := h.Queries.CreateAnswer(r.Context(), store.CreateAnswerParams{
				ID:         newAnswerID(),
				QuestionID: qRow.ID,
				Text:       ga.Text,
				IsCorrect:  ga.IsCorrect,
				Position:   int32(i),
				CreatedBy:  currentUser.Username,
				UpdatedBy:  currentUser.Username,
			})
			if aErr != nil {
				continue
			}
			answers = append(answers, savedAnswer{
				ID:        aRow.ID,
				Text:      aRow.Text,
				IsCorrect: aRow.IsCorrect,
				Position:  int(aRow.Position),
			})
		}

		out = append(out, savedQuestion{
			ID:           qRow.ID,
			QuestionType: qRow.QuestionType,
			Body:         qRow.Body,
			Answers:      answers,
		})
	}

	writeJSON(w, http.StatusCreated, map[string]any{"questions": out, "source_id": src.ID})
}

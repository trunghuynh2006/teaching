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

// ── Question handlers ─────────────────────────────────────────

func (h *Handler) ListSpaceQuestions(w http.ResponseWriter, r *http.Request, _ user.User) {
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
	rows, err := h.Queries.ListQuestionsBySpace(r.Context(), spaceID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.Question, 0, len(rows))
	for _, row := range rows {
		answers, _ := h.Queries.ListAnswersByQuestion(r.Context(), row.ID)
		out = append(out, toSharedQuestion(row, answers))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetQuestion(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Question id is required"})
		return
	}
	row, err := h.Queries.GetQuestionByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Question not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	answers, _ := h.Queries.ListAnswersByQuestion(r.Context(), id)
	writeJSON(w, http.StatusOK, toSharedQuestion(row, answers))
}

func (h *Handler) CreateQuestion(w http.ResponseWriter, r *http.Request, currentUser user.User) {
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
	input, err := decodeQuestionInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.CreateQuestion(r.Context(), store.CreateQuestionParams{
		ID:           newQuestionID(),
		SpaceID:      spaceID,
		QuestionType: input.QuestionType,
		Body:         input.Body,
		CreatedBy:    currentUser.Username,
		UpdatedBy:    currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedQuestion(row, nil))
}

func (h *Handler) UpdateQuestion(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Question id is required"})
		return
	}
	input, err := decodeQuestionInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateQuestion(r.Context(), store.UpdateQuestionParams{
		ID:           id,
		QuestionType: input.QuestionType,
		Body:         input.Body,
		UpdatedBy:    currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Question not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	answers, _ := h.Queries.ListAnswersByQuestion(r.Context(), id)
	writeJSON(w, http.StatusOK, toSharedQuestion(row, answers))
}

func (h *Handler) DeleteQuestion(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Question id is required"})
		return
	}
	if err := h.Queries.DeleteQuestion(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Answer handlers ───────────────────────────────────────────

func (h *Handler) CreateAnswer(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	questionID := strings.TrimSpace(r.PathValue("id"))
	if questionID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Question id is required"})
		return
	}
	if _, err := h.Queries.GetQuestionByID(r.Context(), questionID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Question not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	input, err := decodeAnswerInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	count, _ := h.Queries.CountAnswersByQuestion(r.Context(), questionID)
	row, err := h.Queries.CreateAnswer(r.Context(), store.CreateAnswerParams{
		ID:         newAnswerID(),
		QuestionID: questionID,
		Text:       input.Text,
		IsCorrect:  input.IsCorrect,
		Position:   int32(count),
		CreatedBy:  currentUser.Username,
		UpdatedBy:  currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedAnswer(row))
}

func (h *Handler) UpdateAnswer(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Answer id is required"})
		return
	}
	existing, err := h.Queries.GetAnswerByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Answer not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	input, err := decodeAnswerInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateAnswer(r.Context(), store.UpdateAnswerParams{
		ID:        id,
		Text:      input.Text,
		IsCorrect: input.IsCorrect,
		Position:  existing.Position,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedAnswer(row))
}

func (h *Handler) DeleteAnswer(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Answer id is required"})
		return
	}
	if err := h.Queries.DeleteAnswer(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Helpers ───────────────────────────────────────────────────

type questionInput struct {
	QuestionType string
	Body         string
}

type answerInput struct {
	Text      string
	IsCorrect bool
}

func decodeQuestionInput(r *http.Request) (questionInput, error) {
	var payload struct {
		QuestionType string `json:"question_type"`
		Body         string `json:"body"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return questionInput{}, errors.New("Invalid request body")
	}
	body := strings.TrimSpace(payload.Body)
	if body == "" {
		return questionInput{}, errors.New("Body is required")
	}
	return questionInput{
		QuestionType: strings.TrimSpace(payload.QuestionType),
		Body:         body,
	}, nil
}

func decodeAnswerInput(r *http.Request) (answerInput, error) {
	var payload struct {
		Text      string `json:"text"`
		IsCorrect bool   `json:"is_correct"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return answerInput{}, errors.New("Invalid request body")
	}
	text := strings.TrimSpace(payload.Text)
	if text == "" {
		return answerInput{}, errors.New("Text is required")
	}
	return answerInput{Text: text, IsCorrect: payload.IsCorrect}, nil
}

func newQuestionID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "ques_" + time.Now().UTC().Format("20060102150405")
	}
	return "ques_" + hex.EncodeToString(b[:])
}

func newAnswerID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "ans_" + time.Now().UTC().Format("20060102150405")
	}
	return "ans_" + hex.EncodeToString(b[:])
}

func toSharedQuestion(q store.Question, answers []store.Answer) sharedmodels.Question {
	out := sharedmodels.Question{
		Id:           q.ID,
		SpaceId:      q.SpaceID,
		QuestionType: q.QuestionType,
		Body:         q.Body,
		CreatedBy:    &q.CreatedBy,
		UpdatedBy:    &q.UpdatedBy,
	}
	if q.CreatedTime.Valid {
		ts := q.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if q.UpdatedTime.Valid {
		ts := q.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	out.Answers = make([]sharedmodels.Answer, 0, len(answers))
	for _, a := range answers {
		out.Answers = append(out.Answers, toSharedAnswer(a))
	}
	return out
}

func toSharedAnswer(a store.Answer) sharedmodels.Answer {
	pos := int(a.Position)
	out := sharedmodels.Answer{
		Id:         a.ID,
		QuestionId: a.QuestionID,
		Text:       a.Text,
		IsCorrect:  a.IsCorrect,
		Position:   &pos,
		CreatedBy:  &a.CreatedBy,
		UpdatedBy:  &a.UpdatedBy,
	}
	if a.CreatedTime.Valid {
		ts := a.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if a.UpdatedTime.Valid {
		ts := a.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

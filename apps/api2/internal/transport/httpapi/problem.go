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

// ── Problem handlers ──────────────────────────────────────────

func (h *Handler) ListSpaceProblems(w http.ResponseWriter, r *http.Request, _ user.User) {
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
	rows, err := h.Queries.ListProblemsBySpace(r.Context(), spaceID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.Problem, 0, len(rows))
	for _, row := range rows {
		steps, _ := h.Queries.ListProblemSteps(r.Context(), row.ID)
		out = append(out, toSharedProblem(row, steps))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetProblem(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Problem id is required"})
		return
	}
	row, err := h.Queries.GetProblemByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Problem not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	steps, _ := h.Queries.ListProblemSteps(r.Context(), id)
	writeJSON(w, http.StatusOK, toSharedProblem(row, steps))
}

func (h *Handler) CreateProblem(w http.ResponseWriter, r *http.Request, currentUser user.User) {
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
	input, err := decodeProblemInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.CreateProblem(r.Context(), store.CreateProblemParams{
		ID:        newProblemID(),
		SpaceID:   spaceID,
		Question:  input.Question,
		Solution:  input.Solution,
		CreatedBy: currentUser.Username,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedProblem(row, nil))
}

func (h *Handler) UpdateProblem(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Problem id is required"})
		return
	}
	input, err := decodeProblemInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateProblem(r.Context(), store.UpdateProblemParams{
		ID:        id,
		Question:  input.Question,
		Solution:  input.Solution,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Problem not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	steps, _ := h.Queries.ListProblemSteps(r.Context(), id)
	writeJSON(w, http.StatusOK, toSharedProblem(row, steps))
}

func (h *Handler) DeleteProblem(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Problem id is required"})
		return
	}
	if err := h.Queries.DeleteProblem(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── ProblemStep handlers ──────────────────────────────────────

func (h *Handler) CreateProblemStep(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	problemID := strings.TrimSpace(r.PathValue("id"))
	if problemID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Problem id is required"})
		return
	}
	if _, err := h.Queries.GetProblemByID(r.Context(), problemID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Problem not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	input, err := decodeProblemStepInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	count, _ := h.Queries.CountProblemSteps(r.Context(), problemID)
	row, err := h.Queries.CreateProblemStep(r.Context(), store.CreateProblemStepParams{
		ID:        newProblemStepID(),
		ProblemID: problemID,
		Body:      input.Body,
		Position:  int32(count),
		CreatedBy: currentUser.Username,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedProblemStep(row))
}

func (h *Handler) UpdateProblemStep(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Problem step id is required"})
		return
	}
	existing, err := h.Queries.GetProblemStepByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Problem step not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	input, err := decodeProblemStepInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateProblemStep(r.Context(), store.UpdateProblemStepParams{
		ID:        id,
		Body:      input.Body,
		Position:  existing.Position,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedProblemStep(row))
}

func (h *Handler) DeleteProblemStep(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Problem step id is required"})
		return
	}
	if err := h.Queries.DeleteProblemStep(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Helpers ───────────────────────────────────────────────────

type problemInput struct {
	Question string
	Solution string
}

type problemStepInput struct {
	Body string
}

func decodeProblemInput(r *http.Request) (problemInput, error) {
	var payload struct {
		Question string `json:"question"`
		Solution string `json:"solution"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return problemInput{}, errors.New("Invalid request body")
	}
	question := strings.TrimSpace(payload.Question)
	if question == "" {
		return problemInput{}, errors.New("Question is required")
	}
	return problemInput{
		Question: question,
		Solution: strings.TrimSpace(payload.Solution),
	}, nil
}

func decodeProblemStepInput(r *http.Request) (problemStepInput, error) {
	var payload struct {
		Body string `json:"body"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return problemStepInput{}, errors.New("Invalid request body")
	}
	body := strings.TrimSpace(payload.Body)
	if body == "" {
		return problemStepInput{}, errors.New("Body is required")
	}
	return problemStepInput{Body: body}, nil
}

func newProblemID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "prob_" + time.Now().UTC().Format("20060102150405")
	}
	return "prob_" + hex.EncodeToString(b[:])
}

func newProblemStepID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "pstep_" + time.Now().UTC().Format("20060102150405")
	}
	return "pstep_" + hex.EncodeToString(b[:])
}

func toSharedProblem(p store.Problem, steps []store.ProblemStep) sharedmodels.Problem {
	out := sharedmodels.Problem{
		Id:        p.ID,
		SpaceId:   p.SpaceID,
		Question:  p.Question,
		Solution:  p.Solution,
		CreatedBy: &p.CreatedBy,
		UpdatedBy: &p.UpdatedBy,
	}
	if p.CreatedTime.Valid {
		ts := p.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if p.UpdatedTime.Valid {
		ts := p.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	out.Steps = make([]sharedmodels.ProblemStep, 0, len(steps))
	for _, s := range steps {
		out.Steps = append(out.Steps, toSharedProblemStep(s))
	}
	return out
}

func toSharedProblemStep(s store.ProblemStep) sharedmodels.ProblemStep {
	pos := int(s.Position)
	out := sharedmodels.ProblemStep{
		Id:        s.ID,
		ProblemId: s.ProblemID,
		Body:      s.Body,
		Position:  &pos,
		CreatedBy: &s.CreatedBy,
		UpdatedBy: &s.UpdatedBy,
	}
	if s.CreatedTime.Valid {
		ts := s.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if s.UpdatedTime.Valid {
		ts := s.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

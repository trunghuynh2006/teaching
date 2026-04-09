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

// ─── Response types ──────────────────────────────────────────────────────────

type learningPathResponse struct {
	ID          string                    `json:"id"`
	Title       string                    `json:"title"`
	Description string                    `json:"description,omitempty"`
	Domain      string                    `json:"domain,omitempty"`
	Status      string                    `json:"status"`
	CreatedBy   string                    `json:"created_by,omitempty"`
	UpdatedBy   string                    `json:"updated_by,omitempty"`
	CreatedTime string                    `json:"created_time,omitempty"`
	UpdatedTime string                    `json:"updated_time,omitempty"`
	Steps       []learningPathStepResponse `json:"steps,omitempty"`
}

type learningPathStepResponse struct {
	ID          string          `json:"id"`
	Position    int             `json:"position"`
	Note        string          `json:"note,omitempty"`
	Concept     conceptResponse `json:"concept"`
}

func toLearningPathResponse(p store.LearningPath) learningPathResponse {
	r := learningPathResponse{
		ID:          p.ID,
		Title:       p.Title,
		Description: p.Description,
		Domain:      p.Domain,
		Status:      p.Status,
		CreatedBy:   p.CreatedBy,
		UpdatedBy:   p.UpdatedBy,
	}
	if p.CreatedTime.Valid {
		r.CreatedTime = p.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
	}
	if p.UpdatedTime.Valid {
		r.UpdatedTime = p.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
	}
	return r
}

func toLearningPathStepResponse(s store.LearningPathStepWithConcept) learningPathStepResponse {
	return learningPathStepResponse{
		ID:       s.ID,
		Position: s.Position,
		Note:     s.Note,
		Concept:  toConceptResponse(s.Concept),
	}
}

func newLearningPathID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return "lp_" + hex.EncodeToString(b)
}

func newLearningPathStepID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return "lps_" + hex.EncodeToString(b)
}

// ─── CRUD ────────────────────────────────────────────────────────────────────

func (h *Handler) ListLearningPaths(w http.ResponseWriter, r *http.Request, _ user.User) {
	domain := strings.TrimSpace(r.URL.Query().Get("domain"))
	var (
		paths []store.LearningPath
		err   error
	)
	if domain != "" {
		paths, err = h.Queries.ListLearningPathsByDomain(r.Context(), domain)
	} else {
		paths, err = h.Queries.ListLearningPaths(r.Context())
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]learningPathResponse, 0, len(paths))
	for _, p := range paths {
		out = append(out, toLearningPathResponse(p))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetLearningPath(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "id is required"})
		return
	}
	p, err := h.Queries.GetLearningPathByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Learning path not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	resp := toLearningPathResponse(p)
	steps, _ := h.Queries.ListLearningPathSteps(r.Context(), id)
	for _, s := range steps {
		resp.Steps = append(resp.Steps, toLearningPathStepResponse(s))
	}
	if resp.Steps == nil {
		resp.Steps = []learningPathStepResponse{}
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) CreateLearningPath(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	input, err := decodeLearningPathInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	p, err := h.Queries.CreateLearningPath(r.Context(), store.CreateLearningPathParams{
		ID:          newLearningPathID(),
		Title:       input.Title,
		Description: input.Description,
		Domain:      input.Domain,
		Status:      input.Status,
		CreatedBy:   currentUser.Username,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toLearningPathResponse(p))
}

func (h *Handler) UpdateLearningPath(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "id is required"})
		return
	}
	input, err := decodeLearningPathInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	p, err := h.Queries.UpdateLearningPath(r.Context(), store.UpdateLearningPathParams{
		ID:          id,
		Title:       input.Title,
		Description: input.Description,
		Domain:      input.Domain,
		Status:      input.Status,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Learning path not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toLearningPathResponse(p))
}

func (h *Handler) DeleteLearningPath(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "id is required"})
		return
	}
	if err := h.Queries.DeleteLearningPath(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── Steps ───────────────────────────────────────────────────────────────────

func (h *Handler) ListLearningPathSteps(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	steps, err := h.Queries.ListLearningPathSteps(r.Context(), id)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]learningPathStepResponse, 0, len(steps))
	for _, s := range steps {
		out = append(out, toLearningPathStepResponse(s))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) AddLearningPathStep(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "id is required"})
		return
	}
	var payload struct {
		ConceptID string `json:"concept_id"`
		Position  int    `json:"position"`
		Note      string `json:"note"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || strings.TrimSpace(payload.ConceptID) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "concept_id is required"})
		return
	}
	if err := h.Queries.AddLearningPathStep(r.Context(), store.AddLearningPathStepParams{
		ID:        newLearningPathStepID(),
		PathID:    id,
		ConceptID: strings.TrimSpace(payload.ConceptID),
		Position:  payload.Position,
		Note:      strings.TrimSpace(payload.Note),
		CreatedBy: currentUser.Username,
	}); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) RemoveLearningPathStep(w http.ResponseWriter, r *http.Request, _ user.User) {
	pathID := strings.TrimSpace(r.PathValue("id"))
	conceptID := strings.TrimSpace(r.PathValue("concept_id"))
	if pathID == "" || conceptID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "id and concept_id are required"})
		return
	}
	if err := h.Queries.RemoveLearningPathStep(r.Context(), pathID, conceptID); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ReorderLearningPathStep(w http.ResponseWriter, r *http.Request, _ user.User) {
	pathID := strings.TrimSpace(r.PathValue("id"))
	conceptID := strings.TrimSpace(r.PathValue("concept_id"))
	if pathID == "" || conceptID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "id and concept_id are required"})
		return
	}
	var payload struct {
		Position int `json:"position"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "position is required"})
		return
	}
	if err := h.Queries.ReorderLearningPathStep(r.Context(), pathID, conceptID, payload.Position); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

type learningPathInput struct {
	Title       string
	Description string
	Domain      string
	Status      string
}

func decodeLearningPathInput(r *http.Request) (learningPathInput, error) {
	var payload struct {
		Title       string `json:"title"`
		Description string `json:"description"`
		Domain      string `json:"domain"`
		Status      string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return learningPathInput{}, errors.New("invalid request body")
	}
	title := strings.TrimSpace(payload.Title)
	if title == "" {
		return learningPathInput{}, errors.New("title is required")
	}
	status := strings.TrimSpace(payload.Status)
	if status == "" {
		status = "draft"
	}
	return learningPathInput{
		Title:       title,
		Description: strings.TrimSpace(payload.Description),
		Domain:      strings.TrimSpace(payload.Domain),
		Status:      status,
	}, nil
}

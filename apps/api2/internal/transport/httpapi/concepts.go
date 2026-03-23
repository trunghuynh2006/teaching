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

// ─── Concept CRUD ────────────────────────────────────────────────────────────

func (h *Handler) ListConcepts(w http.ResponseWriter, r *http.Request, _ user.User) {
	domain := strings.TrimSpace(r.URL.Query().Get("domain"))
	var (
		rows []store.Concept
		err  error
	)
	if domain != "" {
		rows, err = h.Queries.ListConceptsByDomain(r.Context(), domain)
	} else {
		rows, err = h.Queries.ListConcepts(r.Context())
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.Concept, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedConcept(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetConcept(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Concept id is required"})
		return
	}
	row, err := h.Queries.GetConceptByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Concept not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedConcept(row))
}

func (h *Handler) CreateConcept(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	input, err := decodeConceptInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.CreateConcept(r.Context(), store.CreateConceptParams{
		ID:            newConceptID(),
		CanonicalName: input.CanonicalName,
		Domain:        input.Domain,
		Description:   input.Description,
		Tags:          input.Tags,
		CreatedBy:     currentUser.Username,
		UpdatedBy:     currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedConcept(row))
}

func (h *Handler) UpdateConcept(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Concept id is required"})
		return
	}
	input, err := decodeConceptInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateConcept(r.Context(), store.UpdateConceptParams{
		ID:            id,
		CanonicalName: input.CanonicalName,
		Domain:        input.Domain,
		Description:   input.Description,
		Tags:          input.Tags,
		UpdatedBy:     currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Concept not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedConcept(row))
}

func (h *Handler) DeleteConcept(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Concept id is required"})
		return
	}
	if err := h.Queries.DeleteConcept(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── Source ↔ Concept ────────────────────────────────────────────────────────

func (h *Handler) ListSourceConcepts(w http.ResponseWriter, r *http.Request, _ user.User) {
	sourceID := strings.TrimSpace(r.PathValue("id"))
	if sourceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Source id is required"})
		return
	}
	rows, err := h.Queries.ListConceptsBySource(r.Context(), sourceID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.Concept, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedConcept(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) LinkSourceConcept(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	sourceID := strings.TrimSpace(r.PathValue("id"))
	if sourceID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Source id is required"})
		return
	}
	var payload struct {
		ConceptID string `json:"concept_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || strings.TrimSpace(payload.ConceptID) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "concept_id is required"})
		return
	}
	if err := h.Queries.LinkSourceConcept(r.Context(), sourceID, strings.TrimSpace(payload.ConceptID), currentUser.Username); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) UnlinkSourceConcept(w http.ResponseWriter, r *http.Request, _ user.User) {
	sourceID := strings.TrimSpace(r.PathValue("id"))
	conceptID := strings.TrimSpace(r.PathValue("concept_id"))
	if sourceID == "" || conceptID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Source id and concept id are required"})
		return
	}
	if err := h.Queries.UnlinkSourceConcept(r.Context(), sourceID, conceptID); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── Topic ↔ Concept ─────────────────────────────────────────────────────────

func (h *Handler) ListTopicConcepts(w http.ResponseWriter, r *http.Request, _ user.User) {
	topicID := strings.TrimSpace(r.PathValue("id"))
	if topicID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Topic id is required"})
		return
	}
	rows, err := h.Queries.ListConceptsByTopic(r.Context(), topicID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.Concept, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedConcept(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) LinkTopicConcept(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	topicID := strings.TrimSpace(r.PathValue("id"))
	if topicID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Topic id is required"})
		return
	}
	var payload struct {
		ConceptID string `json:"concept_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || strings.TrimSpace(payload.ConceptID) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "concept_id is required"})
		return
	}
	if err := h.Queries.LinkTopicConcept(r.Context(), topicID, strings.TrimSpace(payload.ConceptID), currentUser.Username); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) UnlinkTopicConcept(w http.ResponseWriter, r *http.Request, _ user.User) {
	topicID := strings.TrimSpace(r.PathValue("id"))
	conceptID := strings.TrimSpace(r.PathValue("concept_id"))
	if topicID == "" || conceptID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Topic id and concept id are required"})
		return
	}
	if err := h.Queries.UnlinkTopicConcept(r.Context(), topicID, conceptID); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

type conceptInput struct {
	CanonicalName string
	Domain        string
	Description   string
	Tags          []string
}

func decodeConceptInput(r *http.Request) (conceptInput, error) {
	var payload struct {
		CanonicalName string   `json:"canonical_name"`
		Domain        string   `json:"domain"`
		Description   string   `json:"description"`
		Tags          []string `json:"tags"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return conceptInput{}, errors.New("Invalid request body")
	}
	name := strings.TrimSpace(payload.CanonicalName)
	if name == "" {
		return conceptInput{}, errors.New("canonical_name is required")
	}
	tags := payload.Tags
	if tags == nil {
		tags = []string{}
	}
	return conceptInput{
		CanonicalName: name,
		Domain:        strings.TrimSpace(payload.Domain),
		Description:   strings.TrimSpace(payload.Description),
		Tags:          tags,
	}, nil
}

func toSharedConcept(c store.Concept) sharedmodels.Concept {
	out := sharedmodels.Concept{
		Id:            c.ID,
		CanonicalName: c.CanonicalName,
		Tags:          c.Tags,
	}
	if c.Domain != "" {
		out.Domain = &c.Domain
	}
	if c.Description != "" {
		out.Description = &c.Description
	}
	if c.CreatedBy != "" {
		out.CreatedBy = &c.CreatedBy
	}
	if c.UpdatedBy != "" {
		out.UpdatedBy = &c.UpdatedBy
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

func newConceptID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "concept_" + time.Now().UTC().Format("20060102150405")
	}
	return "concept_" + hex.EncodeToString(b[:])
}

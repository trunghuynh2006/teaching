package httpapi

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"api2/internal/domain/user"
	infra_ai "api2/internal/infra/ai"
	"api2/internal/sharedmodels"
	"api2/internal/store"

	"github.com/jackc/pgx/v5"
)

// conceptResponse is the JSON shape returned for all concept endpoints.
// Richer than sharedmodels.Concept — includes level, scope, and optional prerequisites.
type conceptResponse struct {
	ID            string            `json:"id"`
	CanonicalName string            `json:"canonical_name"`
	Domain        string            `json:"domain,omitempty"`
	Description   string            `json:"description,omitempty"`
	Tags          []string          `json:"tags,omitempty"`
	Level         string            `json:"level"`
	Scope         string            `json:"scope"`
	CreatedBy     string            `json:"created_by,omitempty"`
	UpdatedBy     string            `json:"updated_by,omitempty"`
	CreatedTime   string            `json:"created_time,omitempty"`
	UpdatedTime   string            `json:"updated_time,omitempty"`
	Prerequisites []conceptResponse `json:"prerequisites,omitempty"`
}

func toConceptResponse(c store.Concept) conceptResponse {
	r := conceptResponse{
		ID:            c.ID,
		CanonicalName: c.CanonicalName,
		Domain:        c.Domain,
		Description:   c.Description,
		Tags:          c.Tags,
		Level:         c.Level,
		Scope:         c.Scope,
		CreatedBy:     c.CreatedBy,
		UpdatedBy:     c.UpdatedBy,
	}
	if r.Tags == nil {
		r.Tags = []string{}
	}
	if c.CreatedTime.Valid {
		r.CreatedTime = c.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
	}
	if c.UpdatedTime.Valid {
		r.UpdatedTime = c.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
	}
	return r
}

// ─── Concept CRUD ────────────────────────────────────────────────────────────

func (h *Handler) ListConcepts(w http.ResponseWriter, r *http.Request, _ user.User) {
	domain := strings.TrimSpace(r.URL.Query().Get("domain"))
	level := strings.TrimSpace(r.URL.Query().Get("level"))
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
	out := make([]conceptResponse, 0, len(rows))
	for _, row := range rows {
		if level != "" && row.Level != level {
			continue
		}
		out = append(out, toConceptResponse(row))
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
	resp := toConceptResponse(row)
	// Embed prerequisites inline
	prereqs, _ := h.Queries.ListConceptPrerequisites(r.Context(), id)
	for _, p := range prereqs {
		resp.Prerequisites = append(resp.Prerequisites, toConceptResponse(p))
	}
	writeJSON(w, http.StatusOK, resp)
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
		Level:         input.Level,
		Scope:         input.Scope,
		CreatedBy:     currentUser.Username,
		UpdatedBy:     currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toConceptResponse(row))
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
		Level:         input.Level,
		Scope:         input.Scope,
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
	writeJSON(w, http.StatusOK, toConceptResponse(row))
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

// ─── Prerequisites ───────────────────────────────────────────────────────────

func (h *Handler) ListConceptPrerequisites(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	rows, err := h.Queries.ListConceptPrerequisites(r.Context(), id)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]conceptResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, toConceptResponse(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) AddConceptPrerequisite(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	var payload struct {
		PrerequisiteID string `json:"prerequisite_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || strings.TrimSpace(payload.PrerequisiteID) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "prerequisite_id is required"})
		return
	}
	if err := h.Queries.AddConceptPrerequisite(r.Context(), id, strings.TrimSpace(payload.PrerequisiteID), currentUser.Username); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) RemoveConceptPrerequisite(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	prereqID := strings.TrimSpace(r.PathValue("prerequisite_id"))
	if err := h.Queries.RemoveConceptPrerequisite(r.Context(), id, prereqID); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── Seed domain foundation concepts ─────────────────────────────────────────

// SeedDomainConcepts calls the AI to generate foundation concepts for a domain
// and persists them if they don't already exist (matched by canonical_name+domain).
func (h *Handler) SeedDomainConcepts(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	var payload struct {
		Domain string `json:"domain"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || strings.TrimSpace(payload.Domain) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "domain is required"})
		return
	}
	domain := strings.TrimSpace(payload.Domain)

	if h.AIClient == nil {
		writeJSON(w, http.StatusServiceUnavailable, ErrorResponse{Detail: "AI service not configured"})
		return
	}

	serviceToken, err := h.AuthService.Tokens.CreateAccessToken("api2-service", "teacher")
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	generated, err := h.AIClient.SeedFoundationConcepts(ctx, serviceToken, infra_ai.SeedFoundationConceptsRequest{
		Domain: domain,
	})
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}

	// Fetch existing concepts for dedup
	existing, _ := h.Queries.ListConceptsByDomain(r.Context(), domain)
	existingNames := make(map[string]bool, len(existing))
	for _, c := range existing {
		existingNames[strings.ToLower(c.CanonicalName)] = true
	}

	created := make([]conceptResponse, 0, len(generated))
	for _, gc := range generated {
		if existingNames[strings.ToLower(gc.CanonicalName)] {
			continue
		}
		row, err := h.Queries.CreateConcept(r.Context(), store.CreateConceptParams{
			ID:            newConceptID(),
			CanonicalName: gc.CanonicalName,
			Domain:        domain,
			Description:   gc.Description,
			Tags:          gc.Tags,
			Level:         gc.Level,
			Scope:         gc.Scope,
			CreatedBy:     currentUser.Username,
			UpdatedBy:     currentUser.Username,
		})
		if err != nil {
			continue
		}
		created = append(created, toConceptResponse(row))
	}

	writeJSON(w, http.StatusCreated, map[string]any{"concepts": created, "domain": domain})
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
	Level         string
	Scope         string
}

func decodeConceptInput(r *http.Request) (conceptInput, error) {
	var payload struct {
		CanonicalName string   `json:"canonical_name"`
		Domain        string   `json:"domain"`
		Description   string   `json:"description"`
		Tags          []string `json:"tags"`
		Level         string   `json:"level"`
		Scope         string   `json:"scope"`
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
		Level:         strings.TrimSpace(payload.Level),
		Scope:         strings.TrimSpace(payload.Scope),
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

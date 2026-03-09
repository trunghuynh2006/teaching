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

var allowedSkillDifficulties = map[string]struct{}{
	"beginner":     {},
	"intermediate": {},
	"advanced":     {},
}

func (h *Handler) ListSkills(w http.ResponseWriter, r *http.Request, _ user.User) {
	rows, err := h.Queries.ListSkills(r.Context())
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	out := make([]sharedmodels.Skill, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedSkill(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetSkill(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Skill id is required"})
		return
	}

	row, err := h.Queries.GetSkillByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Skill not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedSkill(row))
}

func (h *Handler) CreateSkill(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageSkills(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	input, err := decodeSkillInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.CreateSkill(r.Context(), store.CreateSkillParams{
		ID:          newSkillID(),
		Title:       input.Title,
		Description: input.Description,
		Difficulty:  input.Difficulty,
		Tags:        input.Tags,
		CreatedBy:   currentUser.Username,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusCreated, toSharedSkill(row))
}

func (h *Handler) UpdateSkill(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageSkills(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Skill id is required"})
		return
	}

	input, err := decodeSkillInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.UpdateSkillByID(r.Context(), store.UpdateSkillByIDParams{
		ID:          id,
		Title:       input.Title,
		Description: input.Description,
		Difficulty:  input.Difficulty,
		Tags:        input.Tags,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Skill not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedSkill(row))
}

func (h *Handler) ArchiveSkill(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageSkills(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Skill id is required"})
		return
	}

	row, err := h.Queries.ArchiveSkillByID(r.Context(), store.ArchiveSkillByIDParams{
		ID:        id,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Skill not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedSkill(row))
}

func (h *Handler) PublishSkill(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageSkills(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Skill id is required"})
		return
	}

	row, err := h.Queries.PublishSkillByID(r.Context(), store.PublishSkillByIDParams{
		ID:        id,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Skill not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedSkill(row))
}

func (h *Handler) MoveSkillToDraft(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageSkills(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Skill id is required"})
		return
	}

	row, err := h.Queries.MoveSkillToDraftByID(r.Context(), store.MoveSkillToDraftByIDParams{
		ID:        id,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Skill not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedSkill(row))
}

func decodeSkillInput(r *http.Request) (skillInput, error) {
	var payload sharedmodels.SkillInput
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return skillInput{}, errors.New("Invalid request body")
	}

	title := strings.TrimSpace(payload.Title)
	if title == "" {
		return skillInput{}, errors.New("Title is required")
	}

	description := ""
	if payload.Description != nil {
		description = strings.TrimSpace(*payload.Description)
	}

	difficulty := "beginner"
	if payload.Difficulty != nil {
		difficulty = strings.TrimSpace(strings.ToLower(*payload.Difficulty))
	}
	if _, ok := allowedSkillDifficulties[difficulty]; !ok {
		return skillInput{}, errors.New("Difficulty must be one of: beginner, intermediate, advanced")
	}

	return skillInput{
		Title:       title,
		Description: description,
		Difficulty:  difficulty,
		Tags:        sanitizeTags(payload.Tags),
	}, nil
}

func sanitizeTags(tags []string) []string {
	if len(tags) == 0 {
		return []string{}
	}

	seen := make(map[string]struct{}, len(tags))
	out := make([]string, 0, len(tags))
	for _, raw := range tags {
		tag := strings.TrimSpace(raw)
		if tag == "" {
			continue
		}
		key := strings.ToLower(tag)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, tag)
	}
	return out
}

func newSkillID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "skill_" + time.Now().UTC().Format("20060102150405")
	}
	return "skill_" + hex.EncodeToString(b[:])
}

func canManageSkills(role string) bool {
	return role == "teacher" || role == "admin"
}

func toSharedSkill(s store.Skill) sharedmodels.Skill {
	createdBy := s.CreatedBy
	updatedBy := s.UpdatedBy
	difficulty := s.Difficulty
	status := s.Status

	out := sharedmodels.Skill{
		Id:          s.ID,
		Title:       s.Title,
		Description: &s.Description,
		Difficulty:  &difficulty,
		Status:      &status,
		Tags:        s.Tags,
		CreatedBy:   &createdBy,
		UpdatedBy:   &updatedBy,
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

type skillInput struct {
	Title       string
	Description string
	Difficulty  string
	Tags        []string
}

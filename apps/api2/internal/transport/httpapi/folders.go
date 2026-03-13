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

func (h *Handler) ListFolders(w http.ResponseWriter, r *http.Request, _ user.User) {
	rows, err := h.Queries.ListFolders(r.Context())
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	out := make([]sharedmodels.Folder, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedFolder(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetFolder(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	row, err := h.Queries.GetFolderByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Folder not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedFolder(row))
}

func canManageFolders(role string) bool {
	return role == "teacher" || role == "admin" || role == "learner"
}

func (h *Handler) CreateFolder(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	input, err := decodeFolderInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.CreateFolder(r.Context(), store.CreateFolderParams{
		ID:          newFolderID(),
		Name:        input.Name,
		Description: input.Description,
		CreatedBy:   currentUser.Username,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusCreated, toSharedFolder(row))
}

func (h *Handler) UpdateFolder(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	input, err := decodeFolderInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.UpdateFolderByID(r.Context(), store.UpdateFolderByIDParams{
		ID:          id,
		Name:        input.Name,
		Description: input.Description,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Folder not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedFolder(row))
}

func (h *Handler) DeleteFolder(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	if err := h.Queries.DeleteFolderByID(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ListFolderSkills(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	// Verify folder exists.
	if _, err := h.Queries.GetFolderByID(r.Context(), id); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Folder not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	rows, err := h.Queries.ListSkillsInFolder(r.Context(), id)
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

func (h *Handler) AddSkillToFolder(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	folderID := strings.TrimSpace(r.PathValue("id"))
	skillID := strings.TrimSpace(r.PathValue("skill_id"))
	if folderID == "" || skillID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id and skill id are required"})
		return
	}

	if err := h.Queries.AddSkillToFolder(r.Context(), store.AddSkillToFolderParams{
		FolderID: folderID,
		SkillID:  skillID,
		AddedBy:  currentUser.Username,
	}); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) RemoveSkillFromFolder(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	folderID := strings.TrimSpace(r.PathValue("id"))
	skillID := strings.TrimSpace(r.PathValue("skill_id"))
	if folderID == "" || skillID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id and skill id are required"})
		return
	}

	if err := h.Queries.RemoveSkillFromFolder(r.Context(), store.RemoveSkillFromFolderParams{
		FolderID: folderID,
		SkillID:  skillID,
	}); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func decodeFolderInput(r *http.Request) (folderInput, error) {
	var payload struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return folderInput{}, errors.New("Invalid request body")
	}

	name := strings.TrimSpace(payload.Name)
	if name == "" {
		return folderInput{}, errors.New("Name is required")
	}

	return folderInput{
		Name:        name,
		Description: strings.TrimSpace(payload.Description),
	}, nil
}

func newFolderID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "folder_" + time.Now().UTC().Format("20060102150405")
	}
	return "folder_" + hex.EncodeToString(b[:])
}

func toSharedFolder(f store.Folder) sharedmodels.Folder {
	out := sharedmodels.Folder{
		Id:          f.ID,
		Name:        f.Name,
		Description: &f.Description,
		CreatedBy:   &f.CreatedBy,
		UpdatedBy:   &f.UpdatedBy,
	}
	if f.CreatedTime.Valid {
		ts := f.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if f.UpdatedTime.Valid {
		ts := f.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

type folderInput struct {
	Name        string
	Description string
}

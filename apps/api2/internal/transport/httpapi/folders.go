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

	ownerID := currentUser.Username
	row, err := h.Queries.CreateFolder(r.Context(), store.CreateFolderParams{
		ID:          newFolderID(),
		FolderType:  input.FolderType,
		OwnerID:     &ownerID,
		ProgramID:   input.ProgramID,
		IsLocked:    input.IsLocked,
		Name:        input.Name,
		Description: input.Description,
		Domain:      input.Domain,
		Theme:       input.Theme,
		Icon:        input.Icon,
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
		Domain:      input.Domain,
		Theme:       input.Theme,
		Icon:        input.Icon,
		IsLocked:    input.IsLocked,
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

func (h *Handler) ListFolderMembers(w http.ResponseWriter, r *http.Request, _ user.User) {
	folderID := strings.TrimSpace(r.PathValue("id"))
	if folderID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	if _, err := h.Queries.GetFolderByID(r.Context(), folderID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Folder not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	rows, err := h.Queries.ListFolderMembers(r.Context(), folderID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	out := make([]sharedmodels.FolderMember, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedFolderMember(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) AddFolderMember(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	folderID := strings.TrimSpace(r.PathValue("id"))
	if folderID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	var payload struct {
		UserID string `json:"user_id"`
		Role   string `json:"role"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid request body"})
		return
	}
	if strings.TrimSpace(payload.UserID) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "user_id is required"})
		return
	}
	if payload.Role != "viewer" && payload.Role != "editor" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "role must be viewer or editor"})
		return
	}

	addedBy := currentUser.Username
	member, err := h.Queries.AddFolderMember(r.Context(), store.AddFolderMemberParams{
		FolderID: folderID,
		UserID:   payload.UserID,
		Role:     payload.Role,
		AddedBy:  &addedBy,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedFolderMember(member))
}

func (h *Handler) RemoveFolderMember(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	folderID := strings.TrimSpace(r.PathValue("id"))
	userID := strings.TrimSpace(r.PathValue("user_id"))
	if folderID == "" || userID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id and user id are required"})
		return
	}

	if err := h.Queries.RemoveFolderMember(r.Context(), store.RemoveFolderMemberParams{
		FolderID: folderID,
		UserID:   userID,
	}); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func decodeFolderInput(r *http.Request) (folderInput, error) {
	var payload struct {
		FolderType  string  `json:"folder_type"`
		ProgramID   *string `json:"program_id"`
		IsLocked    bool    `json:"is_locked"`
		Name        string  `json:"name"`
		Description string  `json:"description"`
		Domain      *string `json:"domain"`
		Theme       string  `json:"theme"`
		Icon        string  `json:"icon"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return folderInput{}, errors.New("Invalid request body")
	}

	name := strings.TrimSpace(payload.Name)
	if name == "" {
		return folderInput{}, errors.New("Name is required")
	}

	folderType := payload.FolderType
	if folderType == "" {
		folderType = "teacher"
	}
	if folderType != "teacher" && folderType != "learner" && folderType != "program" {
		return folderInput{}, errors.New("folder_type must be one of: teacher, learner, program")
	}
	if folderType == "program" && (payload.ProgramID == nil || strings.TrimSpace(*payload.ProgramID) == "") {
		return folderInput{}, errors.New("program_id is required when folder_type is program")
	}

	return folderInput{
		FolderType:  folderType,
		ProgramID:   payload.ProgramID,
		IsLocked:    payload.IsLocked,
		Name:        name,
		Description: strings.TrimSpace(payload.Description),
		Domain:      payload.Domain,
		Theme:       strings.TrimSpace(payload.Theme),
		Icon:        strings.TrimSpace(payload.Icon),
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
	isLocked := f.IsLocked
	out := sharedmodels.Folder{
		Id:         f.ID,
		FolderType: f.FolderType,
		OwnerId:    f.OwnerID,
		ProgramId:  f.ProgramID,
		IsLocked:   &isLocked,
		Name:       f.Name,
		Description: &f.Description,
		Domain:     f.Domain,
		Theme:      &f.Theme,
		Icon:       &f.Icon,
		CreatedBy:  &f.CreatedBy,
		UpdatedBy:  &f.UpdatedBy,
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

func toSharedFolderMember(m store.FolderMember) sharedmodels.FolderMember {
	out := sharedmodels.FolderMember{
		FolderId: m.FolderID,
		UserId:   m.UserID,
		Role:     m.Role,
		AddedBy:  m.AddedBy,
	}
	if m.AddedTime.Valid {
		ts := m.AddedTime.Time.UTC().Format(time.RFC3339Nano)
		out.AddedTime = &ts
	}
	return out
}

type folderInput struct {
	FolderType  string
	ProgramID   *string
	IsLocked    bool
	Name        string
	Description string
	Domain      *string
	Theme       string
	Icon        string
}

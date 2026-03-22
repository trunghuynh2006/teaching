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

func (h *Handler) ListFolderTopics(w http.ResponseWriter, r *http.Request, _ user.User) {
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

	rows, err := h.Queries.ListTopicsByFolder(r.Context(), folderID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	out := make([]sharedmodels.Topic, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedTopic(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) CreateTopic(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	folderID := strings.TrimSpace(r.PathValue("id"))
	if folderID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	input, err := decodeTopicInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.CreateTopic(r.Context(), store.CreateTopicParams{
		ID:          newTopicID(),
		Name:        input.Name,
		FolderID:    folderID,
		Description: input.Description,
		CreatedBy:   currentUser.Username,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusCreated, toSharedTopic(row))
}

func (h *Handler) UpdateTopic(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Topic id is required"})
		return
	}

	input, err := decodeTopicInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.UpdateTopic(r.Context(), store.UpdateTopicParams{
		ID:          id,
		Name:        input.Name,
		Description: input.Description,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Topic not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedTopic(row))
}

func (h *Handler) DeleteTopic(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if !canManageFolders(currentUser.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		return
	}

	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Topic id is required"})
		return
	}

	if err := h.Queries.DeleteTopic(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func toSharedTopic(t store.Topic) sharedmodels.Topic {
	out := sharedmodels.Topic{
		Id:       t.ID,
		Name:     t.Name,
		FolderId: t.FolderID,
	}
	if t.Description != "" {
		out.Description = &t.Description
	}
	if t.CreatedBy != "" {
		out.CreatedBy = &t.CreatedBy
	}
	if t.UpdatedBy != "" {
		out.UpdatedBy = &t.UpdatedBy
	}
	if t.CreatedTime.Valid {
		ts := t.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if t.UpdatedTime.Valid {
		ts := t.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

func decodeTopicInput(r *http.Request) (struct{ Name, Description string }, error) {
	var payload struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return struct{ Name, Description string }{}, errors.New("Invalid request body")
	}
	name := strings.TrimSpace(payload.Name)
	if name == "" {
		return struct{ Name, Description string }{}, errors.New("Name is required")
	}
	return struct{ Name, Description string }{Name: name, Description: strings.TrimSpace(payload.Description)}, nil
}

func newTopicID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "topic_" + time.Now().UTC().Format("20060102150405")
	}
	return "topic_" + hex.EncodeToString(b[:])
}

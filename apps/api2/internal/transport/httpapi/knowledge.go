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

func (h *Handler) ListFolderKnowledges(w http.ResponseWriter, r *http.Request, _ user.User) {
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

	rows, err := h.Queries.ListKnowledgesByFolder(r.Context(), folderID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	out := make([]sharedmodels.Knowledge, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedKnowledge(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetKnowledge(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Knowledge id is required"})
		return
	}

	row, err := h.Queries.GetKnowledgeByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Knowledge not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedKnowledge(row))
}

func (h *Handler) CreateKnowledge(w http.ResponseWriter, r *http.Request, currentUser user.User) {
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

	input, err := decodeKnowledgeInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.CreateKnowledge(r.Context(), store.CreateKnowledgeParams{
		ID:        newKnowledgeID(),
		FolderID:  folderID,
		Title:     input.Title,
		Content:   input.Content,
		CreatedBy: currentUser.Username,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusCreated, toSharedKnowledge(row))
}

func (h *Handler) UpdateKnowledge(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Knowledge id is required"})
		return
	}

	input, err := decodeKnowledgeInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.UpdateKnowledge(r.Context(), store.UpdateKnowledgeParams{
		ID:        id,
		Title:     input.Title,
		Content:   input.Content,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Knowledge not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedKnowledge(row))
}

func (h *Handler) DeleteKnowledge(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Knowledge id is required"})
		return
	}

	if err := h.Queries.DeleteKnowledge(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func decodeKnowledgeInput(r *http.Request) (knowledgeInput, error) {
	var payload struct {
		Title   string `json:"title"`
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return knowledgeInput{}, errors.New("Invalid request body")
	}

	content := strings.TrimSpace(payload.Content)
	if content == "" {
		return knowledgeInput{}, errors.New("Content is required")
	}

	return knowledgeInput{
		Title:   strings.TrimSpace(payload.Title),
		Content: content,
	}, nil
}

func newKnowledgeID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "know_" + time.Now().UTC().Format("20060102150405")
	}
	return "know_" + hex.EncodeToString(b[:])
}

func toSharedKnowledge(k store.Knowledge) sharedmodels.Knowledge {
	out := sharedmodels.Knowledge{
		Id:        k.ID,
		FolderId:  k.FolderID,
		Title:     &k.Title,
		Content:   k.Content,
		CreatedBy: &k.CreatedBy,
		UpdatedBy: &k.UpdatedBy,
	}
	if k.CreatedTime.Valid {
		ts := k.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if k.UpdatedTime.Valid {
		ts := k.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

type knowledgeInput struct {
	Title   string
	Content string
}

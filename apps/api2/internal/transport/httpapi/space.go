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

// ── Space handlers ───────────────────────────────────────────

func (h *Handler) ListFolderSpaces(w http.ResponseWriter, r *http.Request, _ user.User) {
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
	rows, err := h.Queries.ListSpacesByFolder(r.Context(), folderID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.Space, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedSpace(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetSpace(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
		return
	}
	row, err := h.Queries.GetSpaceByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Space not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedSpace(row))
}

func (h *Handler) CreateSpace(w http.ResponseWriter, r *http.Request, currentUser user.User) {
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
	input, err := decodeSpaceInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.CreateSpace(r.Context(), store.CreateSpaceParams{
		ID:          newSpaceID(),
		FolderID:    folderID,
		Name:        input.Name,
		SpaceType:   input.SpaceType,
		Description: input.Description,
		CreatedBy:   currentUser.Username,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedSpace(row))
}

func (h *Handler) UpdateSpace(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
		return
	}
	input, err := decodeSpaceInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateSpace(r.Context(), store.UpdateSpaceParams{
		ID:          id,
		Name:        input.Name,
		SpaceType:   input.SpaceType,
		Description: input.Description,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Space not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedSpace(row))
}

func (h *Handler) DeleteSpace(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space id is required"})
		return
	}
	if err := h.Queries.DeleteSpace(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── SpaceItem handlers ───────────────────────────────────────

func (h *Handler) ListSpaceItems(w http.ResponseWriter, r *http.Request, _ user.User) {
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
	rows, err := h.Queries.ListSpaceItems(r.Context(), spaceID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	out := make([]sharedmodels.SpaceItem, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedSpaceItem(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) CreateSpaceItem(w http.ResponseWriter, r *http.Request, currentUser user.User) {
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
	input, err := decodeSpaceItemInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	// Auto-position: count existing items
	count, _ := h.Queries.CountSpaceItemsBySpace(r.Context(), spaceID)
	row, err := h.Queries.CreateSpaceItem(r.Context(), store.CreateSpaceItemParams{
		ID:        newSpaceItemID(),
		SpaceID:   spaceID,
		Title:     input.Title,
		Content:   input.Content,
		Position:  int32(count),
		CreatedBy: currentUser.Username,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusCreated, toSharedSpaceItem(row))
}

func (h *Handler) UpdateSpaceItem(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space item id is required"})
		return
	}
	existing, err := h.Queries.GetSpaceItemByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Space item not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	input, err := decodeSpaceItemInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}
	row, err := h.Queries.UpdateSpaceItem(r.Context(), store.UpdateSpaceItemParams{
		ID:        id,
		Title:     input.Title,
		Content:   input.Content,
		Position:  existing.Position,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	writeJSON(w, http.StatusOK, toSharedSpaceItem(row))
}

func (h *Handler) DeleteSpaceItem(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Space item id is required"})
		return
	}
	if err := h.Queries.DeleteSpaceItem(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Helpers ──────────────────────────────────────────────────

func decodeSpaceInput(r *http.Request) (spaceInput, error) {
	var payload struct {
		Name        string `json:"name"`
		SpaceType   string `json:"space_type"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return spaceInput{}, errors.New("Invalid request body")
	}
	name := strings.TrimSpace(payload.Name)
	if name == "" {
		return spaceInput{}, errors.New("Name is required")
	}
	return spaceInput{
		Name:        name,
		SpaceType:   strings.TrimSpace(payload.SpaceType),
		Description: strings.TrimSpace(payload.Description),
	}, nil
}

func decodeSpaceItemInput(r *http.Request) (spaceItemInput, error) {
	var payload struct {
		Title   string `json:"title"`
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return spaceItemInput{}, errors.New("Invalid request body")
	}
	return spaceItemInput{
		Title:   strings.TrimSpace(payload.Title),
		Content: strings.TrimSpace(payload.Content),
	}, nil
}

func newSpaceID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "space_" + time.Now().UTC().Format("20060102150405")
	}
	return "space_" + hex.EncodeToString(b[:])
}

func newSpaceItemID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "sitem_" + time.Now().UTC().Format("20060102150405")
	}
	return "sitem_" + hex.EncodeToString(b[:])
}

func toSharedSpace(s store.Space) sharedmodels.Space {
	out := sharedmodels.Space{
		Id:          s.ID,
		FolderId:    s.FolderID,
		Name:        s.Name,
		SpaceType:   &s.SpaceType,
		Description: &s.Description,
		CreatedBy:   &s.CreatedBy,
		UpdatedBy:   &s.UpdatedBy,
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

func toSharedSpaceItem(si store.SpaceItem) sharedmodels.SpaceItem {
	pos := int(si.Position)
	out := sharedmodels.SpaceItem{
		Id:        si.ID,
		SpaceId:   si.SpaceID,
		Title:     &si.Title,
		Content:   si.Content,
		Position:  &pos,
		CreatedBy: &si.CreatedBy,
		UpdatedBy: &si.UpdatedBy,
	}
	if si.CreatedTime.Valid {
		ts := si.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if si.UpdatedTime.Valid {
		ts := si.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

type spaceInput struct {
	Name        string
	SpaceType   string
	Description string
}

type spaceItemInput struct {
	Title   string
	Content string
}

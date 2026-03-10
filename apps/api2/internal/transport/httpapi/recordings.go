package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"api2/internal/domain/user"
)

const maxChunkBytes = 5 << 20 // 5 MB per chunk

// POST /recordings/sessions
func (h *Handler) CreateRecordingSession(w http.ResponseWriter, r *http.Request, _ user.User) {
	sessionID := newRecordingID()
	dir := filepath.Join(h.uploadDir(), "sessions", sessionID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not create session"})
		return
	}
	// create empty file so the session exists on disk
	f, err := os.Create(filepath.Join(dir, "data.webm"))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not initialise session"})
		return
	}
	f.Close()

	writeJSON(w, http.StatusCreated, map[string]string{"session_id": sessionID})
}

// POST /recordings/sessions/{id}/chunks
// Body: raw audio bytes (no multipart)
func (h *Handler) UploadChunk(w http.ResponseWriter, r *http.Request, _ user.User) {
	sessionID := strings.TrimSpace(r.PathValue("id"))
	if sessionID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "session id is required"})
		return
	}

	dataFile := filepath.Join(h.uploadDir(), "sessions", sessionID, "data.webm")
	f, err := os.OpenFile(dataFile, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		if os.IsNotExist(err) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Session not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not open session"})
		return
	}
	defer f.Close()

	if _, err := io.Copy(f, http.MaxBytesReader(w, r.Body, maxChunkBytes)); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not write chunk"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /recordings/sessions/{id}/finalize
func (h *Handler) FinalizeRecording(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	sessionID := strings.TrimSpace(r.PathValue("id"))
	if sessionID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "session id is required"})
		return
	}

	dataFile := filepath.Join(h.uploadDir(), "sessions", sessionID, "data.webm")
	info, err := os.Stat(dataFile)
	if err != nil {
		if os.IsNotExist(err) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Session not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not read session"})
		return
	}

	id := newRecordingID()
	finalPath := filepath.Join(h.uploadDir(), id+".webm")
	if err := os.Rename(dataFile, finalPath); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not finalise recording"})
		return
	}
	// clean up empty session dir
	_ = os.Remove(filepath.Join(h.uploadDir(), "sessions", sessionID))

	writeJSON(w, http.StatusCreated, map[string]any{
		"id":          id,
		"filename":    id + ".webm",
		"size":        info.Size(),
		"uploaded_by": currentUser.Username,
		"uploaded_at": time.Now().UTC().Format(time.RFC3339),
	})
}

func (h *Handler) uploadDir() string {
	if h.UploadDir != "" {
		return h.UploadDir
	}
	return "./uploads"
}

func newRecordingID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return fmt.Sprintf("rec_%d", time.Now().UnixNano())
	}
	return "rec_" + hex.EncodeToString(b[:])
}

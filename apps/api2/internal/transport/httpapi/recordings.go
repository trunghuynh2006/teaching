package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"api2/internal/domain/user"
)

const maxAudioBytes = 50 << 20 // 50 MB

func (h *Handler) UploadRecording(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	if err := r.ParseMultipartForm(maxAudioBytes); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "File too large or invalid multipart form"})
		return
	}

	file, header, err := r.FormFile("audio")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "audio field is required"})
		return
	}
	defer file.Close()

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".webm"
	}

	id := newRecordingID()
	filename := id + ext

	dir := h.UploadDir
	if dir == "" {
		dir = "./uploads"
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not prepare upload directory"})
		return
	}

	dst, err := os.Create(filepath.Join(dir, filename))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not save file"})
		return
	}
	defer dst.Close()

	size, err := io.Copy(dst, file)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not write file"})
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"id":          id,
		"filename":    filename,
		"size":        size,
		"uploaded_by": currentUser.Username,
		"uploaded_at": time.Now().UTC().Format(time.RFC3339),
	})
}

func newRecordingID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return fmt.Sprintf("rec_%d", time.Now().UnixNano())
	}
	return "rec_" + hex.EncodeToString(b[:])
}

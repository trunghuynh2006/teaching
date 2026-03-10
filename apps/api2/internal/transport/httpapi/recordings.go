package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"api2/internal/domain/user"
	"api2/internal/infra/whisper"
	"api2/internal/store"
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
	f, err := os.Create(filepath.Join(dir, "data.webm"))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not initialise session"})
		return
	}
	f.Close()

	writeJSON(w, http.StatusCreated, map[string]string{"session_id": sessionID})
}

// POST /recordings/sessions/{id}/chunks
// Body: raw audio bytes (no multipart).
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
// Moves the session file to permanent storage, calls Whisper for transcription,
// persists an AudioRecord row, and returns it.
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
	filename := id + ".webm"
	finalPath := filepath.Join(h.uploadDir(), filename)

	if err := os.Rename(dataFile, finalPath); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not finalise recording"})
		return
	}
	_ = os.Remove(filepath.Join(h.uploadDir(), "sessions", sessionID))

	// Transcribe via Whisper — best-effort; log and continue if key missing or API fails.
	transcript := ""
	if h.OpenAIKey != "" {
		client := whisper.Client{APIKey: h.OpenAIKey}
		text, err := client.Transcribe(r.Context(), finalPath)
		if err != nil {
			log.Printf("whisper transcription failed for %s: %v", filename, err)
		} else {
			transcript = text
		}
	}

	rec, err := h.Queries.CreateAudioRecord(r.Context(), store.CreateAudioRecordParams{
		ID:         id,
		UserID:     currentUser.Username,
		Filename:   filename,
		FileSize:   info.Size(),
		Transcript: transcript,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Could not save audio record"})
		return
	}

	writeJSON(w, http.StatusCreated, toAudioRecordResponse(rec))
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
		return fmt.Sprintf("rec_%d", 0) // fallback; rand.Read rarely fails
	}
	return "rec_" + hex.EncodeToString(b[:])
}

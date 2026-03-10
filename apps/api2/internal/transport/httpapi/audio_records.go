package httpapi

import (
	"net/http"
	"time"

	"api2/internal/domain/user"
	"api2/internal/store"
)

type audioRecordResponse struct {
	ID         string `json:"id"`
	UserID     string `json:"user_id"`
	Filename   string `json:"filename"`
	FileSize   int64  `json:"file_size"`
	Transcript string `json:"transcript"`
	CreatedAt  string `json:"created_at"`
}

// GET /audio-records
// Admins see all records; other roles see only their own.
func (h *Handler) ListAudioRecords(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	var (
		rows []store.AudioRecord
		err  error
	)
	if currentUser.Role == "admin" {
		rows, err = h.Queries.ListAudioRecords(r.Context())
	} else {
		rows, err = h.Queries.ListAudioRecordsByUser(r.Context(), currentUser.Username)
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	out := make([]audioRecordResponse, 0, len(rows))
	for _, row := range rows {
		out = append(out, toAudioRecordResponse(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func toAudioRecordResponse(r store.AudioRecord) audioRecordResponse {
	createdAt := ""
	if r.CreatedAt.Valid {
		createdAt = r.CreatedAt.Time.UTC().Format(time.RFC3339)
	}
	return audioRecordResponse{
		ID:         r.ID,
		UserID:     r.UserID,
		Filename:   r.Filename,
		FileSize:   r.FileSize,
		Transcript: r.Transcript,
		CreatedAt:  createdAt,
	}
}

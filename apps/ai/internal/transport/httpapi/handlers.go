package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	appcontent "ai/internal/app/content"
	"ai/internal/infra/security"
	"ai/internal/sharedmodels"
)

type Handler struct {
	ContentService appcontent.Service
	JWT            security.JWT
	AllowedOrigin  string
}

func (h *Handler) Health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ListLessonTitlesRequest is the body for POST /content/lesson-titles.
type ListLessonTitlesRequest struct {
	SkillTitle string `json:"skill_title"`
	Count      int    `json:"count"`
	Audience   string `json:"audience"`
	Difficulty string `json:"difficulty"`
	Language   string `json:"language"`
}

// ListLessonTitlesResponse wraps the generated title candidates.
type ListLessonTitlesResponse struct {
	Titles []string `json:"titles"`
}

// ListLessonTitles handles POST /content/lesson-titles (teacher/admin only).
func (h *Handler) ListLessonTitles(w http.ResponseWriter, r *http.Request, claims security.Claims) {
	if !isContentEditor(claims.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "forbidden"})
		return
	}

	var payload ListLessonTitlesRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "invalid request body"})
		return
	}

	titles, err := h.ContentService.ListLessonTitles(r.Context(), appcontent.ListTitlesInput{
		SkillTitle: payload.SkillTitle,
		Count:      payload.Count,
		Audience:   payload.Audience,
		Difficulty: payload.Difficulty,
		Language:   payload.Language,
	})
	if err != nil {
		switch {
		case errors.Is(err, appcontent.ErrInvalidSkillTitle):
			writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		case errors.Is(err, appcontent.ErrGeneratorUnavailable):
			writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "ai generator unavailable"})
		default:
			writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: "failed to generate lesson titles"})
		}
		return
	}

	writeJSON(w, http.StatusOK, ListLessonTitlesResponse{Titles: titles})
}

// GenerateLessonRequest is the body for POST /content/lesson.
type GenerateLessonRequest struct {
	LessonTitle string `json:"lesson_title"`
	SkillTitle  string `json:"skill_title"`
	Audience    string `json:"audience"`
	Difficulty  string `json:"difficulty"`
	Language    string `json:"language"`
}

// GenerateLessonResponse wraps the generated lesson.
type GenerateLessonResponse struct {
	Lesson sharedmodels.Lesson `json:"lesson"`
}

// GenerateLesson handles POST /content/lesson (teacher/admin only).
func (h *Handler) GenerateLesson(w http.ResponseWriter, r *http.Request, claims security.Claims) {
	if !isContentEditor(claims.Role) {
		writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "forbidden"})
		return
	}

	var payload GenerateLessonRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "invalid request body"})
		return
	}

	lesson, err := h.ContentService.GenerateLesson(r.Context(), appcontent.GenerateLessonInput{
		LessonTitle: payload.LessonTitle,
		SkillTitle:  payload.SkillTitle,
		Audience:    payload.Audience,
		Difficulty:  payload.Difficulty,
		Language:    payload.Language,
	})
	if err != nil {
		switch {
		case errors.Is(err, appcontent.ErrInvalidLessonTitle):
			writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		case errors.Is(err, appcontent.ErrGeneratorUnavailable):
			writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "ai generator unavailable"})
		default:
			writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: "failed to generate lesson"})
		}
		return
	}

	writeJSON(w, http.StatusOK, GenerateLessonResponse{Lesson: lesson})
}

func isContentEditor(role string) bool {
	return role == "teacher" || role == "admin"
}

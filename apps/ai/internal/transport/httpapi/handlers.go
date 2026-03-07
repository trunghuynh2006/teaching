package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	appcontent "ai/internal/app/content"
	"ai/internal/sharedmodels"
)

type Handler struct {
	ContentService appcontent.Service
	AllowedOrigin  string
}

type GenerateContentRequest struct {
	Topic      string `json:"topic"`
	Audience   string `json:"audience"`
	Difficulty string `json:"difficulty"`
	Language   string `json:"language"`
}

type GenerateContentResponse struct {
	Lesson sharedmodels.Lesson `json:"lesson"`
	Skill  sharedmodels.Skill  `json:"skill"`
}

func (h *Handler) Health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) GenerateContent(w http.ResponseWriter, r *http.Request) {
	var payload GenerateContentRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "invalid request body"})
		return
	}

	result, err := h.ContentService.GenerateLessonSkill(r.Context(), appcontent.GenerateInput{
		Topic:      payload.Topic,
		Audience:   payload.Audience,
		Difficulty: payload.Difficulty,
		Language:   payload.Language,
	})
	if err != nil {
		switch {
		case errors.Is(err, appcontent.ErrInvalidTopic):
			writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		case errors.Is(err, appcontent.ErrGeneratorUnavailable):
			writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "ai generator unavailable"})
		default:
			writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: "failed to generate content"})
		}
		return
	}

	writeJSON(w, http.StatusOK, GenerateContentResponse{
		Lesson: result.Lesson,
		Skill:  result.Skill,
	})
}

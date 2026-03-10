package httpapi

import (
	"context"
	"encoding/json"
	"net/http"

	"lesson-plan-generator/internal/domain"
)

type planGenerator interface {
	GeneratePlan(ctx context.Context, lessonID string) (domain.VideoPlan, error)
}

type Handler struct {
	Generator     planGenerator
	AllowedOrigin string
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func (h *Handler) CreatePlan(w http.ResponseWriter, r *http.Request) {
	lessonID := r.PathValue("lesson_id")

	plan, err := h.Generator.GeneratePlan(r.Context(), lessonID)
	if err != nil {
		status := http.StatusInternalServerError
		// detect "not found" from fixtures.Load
		if isNotFound(err) {
			status = http.StatusNotFound
		}
		http.Error(w, err.Error(), status)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(plan)
}

func (h *Handler) CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", h.AllowedOrigin)
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func isNotFound(err error) bool {
	if err == nil {
		return false
	}
	// fixtures.Load wraps the message with "not found"
	return contains(err.Error(), "not found")
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || len(s) > 0 && containsStr(s, sub))
}

func containsStr(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

package httpapi

import (
	"net/http"

	"api2/internal/domain/user"
)

// SearchWikiConcepts handles GET /wiki/concepts/search?q=...&limit=...
func (h *Handler) SearchWikiConcepts(w http.ResponseWriter, r *http.Request, _ user.User) {
	if h.WikiClient == nil {
		writeJSON(w, http.StatusServiceUnavailable, ErrorResponse{Detail: "wiki service not configured"})
		return
	}
	q := r.URL.Query().Get("q")
	if q == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "q is required"})
		return
	}
	results, err := h.WikiClient.SearchConcepts(r.Context(), q, 20)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, results)
}

// GetWikiConceptsByDomain handles GET /wiki/concepts/by-domain?domain=...&limit=...
func (h *Handler) GetWikiConceptsByDomain(w http.ResponseWriter, r *http.Request, _ user.User) {
	if h.WikiClient == nil {
		writeJSON(w, http.StatusServiceUnavailable, ErrorResponse{Detail: "wiki service not configured"})
		return
	}
	domain := r.URL.Query().Get("domain")
	if domain == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "domain is required"})
		return
	}
	results, err := h.WikiClient.GetConceptsByDomain(r.Context(), domain, 50)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, results)
}

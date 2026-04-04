package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"

	appauth "api2/internal/app/auth"
	"api2/internal/app/profile"
	"api2/internal/domain/user"
	infra_ai "api2/internal/infra/ai"
	"api2/internal/infra/wiki"
	"api2/internal/store"
)

type Handler struct {
	AuthService    appauth.Service
	ProfileService profile.Service
	Queries        *store.Queries
	AllowedOrigin  string
	UploadDir      string
	OpenAIKey      string
	AIClient       *infra_ai.Client
	WikiClient     *wiki.Client
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type RolePayload struct {
	Role string         `json:"role"`
	Data map[string]any `json:"data"`
}

func (h *Handler) Health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var payload LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid request body"})
		return
	}

	result, err := h.AuthService.Login(r.Context(), appauth.LoginInput{
		Username: payload.Username,
		Password: payload.Password,
	})
	if err != nil {
		switch err {
		case appauth.ErrInvalidCredentials:
			writeJSON(w, http.StatusUnauthorized, ErrorResponse{Detail: "Invalid username or password"})
		default:
			writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		}
		return
	}

	writeJSON(w, http.StatusOK, result)
}

func (h *Handler) Me(w http.ResponseWriter, _ *http.Request, currentUser user.User) {
	writeJSON(w, http.StatusOK, currentUser.Public())
}

func (h *Handler) RoleData(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	roleName := strings.TrimPrefix(r.URL.Path, "/role/")
	data, err := h.ProfileService.RoleData(currentUser.Role, roleName)
	if err != nil {
		switch err {
		case profile.ErrNotFound:
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Not found"})
		case profile.ErrForbidden:
			writeJSON(w, http.StatusForbidden, ErrorResponse{Detail: "Forbidden for this role"})
		default:
			writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		}
		return
	}

	writeJSON(w, http.StatusOK, RolePayload{Role: roleName, Data: data})
}

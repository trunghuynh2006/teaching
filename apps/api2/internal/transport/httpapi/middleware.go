package httpapi

import (
	"net/http"
	"strings"

	appauth "api2/internal/app/auth"
	"api2/internal/domain/user"
)

type authedHandler func(http.ResponseWriter, *http.Request, user.User)

func (h *Handler) Auth(next authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
			writeJSON(w, http.StatusUnauthorized, ErrorResponse{Detail: "Invalid token"})
			return
		}

		currentUser, err := h.AuthService.Authenticate(r.Context(), parts[1])
		if err != nil {
			switch err {
			case appauth.ErrInvalidToken:
				writeJSON(w, http.StatusUnauthorized, ErrorResponse{Detail: "Invalid token"})
			case appauth.ErrUserNotFound:
				writeJSON(w, http.StatusUnauthorized, ErrorResponse{Detail: "User not found"})
			default:
				writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
			}
			return
		}

		next(w, r, currentUser)
	}
}

func (h *Handler) CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin == h.AllowedOrigin {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

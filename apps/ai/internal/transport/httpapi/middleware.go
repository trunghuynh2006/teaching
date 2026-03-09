package httpapi

import (
	"net/http"
	"strings"

	"ai/internal/infra/security"
)

type authedHandler func(http.ResponseWriter, *http.Request, security.Claims)

// Auth validates the Bearer JWT and passes the claims to the next handler.
func (h *Handler) Auth(next authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		parts := strings.SplitN(r.Header.Get("Authorization"), " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
			writeJSON(w, http.StatusUnauthorized, ErrorResponse{Detail: "missing or invalid token"})
			return
		}
		claims, err := h.JWT.Parse(parts[1])
		if err != nil {
			writeJSON(w, http.StatusUnauthorized, ErrorResponse{Detail: "invalid token"})
			return
		}
		next(w, r, claims)
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

package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	appcontent "ai/internal/app/content"
	"ai/internal/infra/ai/openai"
	"ai/internal/transport/httpapi"

	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

	port := getenv("PORT", "8100")
	allowedOrigin := getenv("ALLOWED_ORIGIN", "http://localhost:5173")
	apiKey := mustGetenv("AI_API_KEY")
	model := getenv("AI_MODEL", "gpt-4o-mini")
	baseURL := strings.TrimSuffix(getenv("AI_BASE_URL", "https://api.openai.com/v1"), "/")

	aiClient := openai.Client{
		APIKey:     apiKey,
		Model:      model,
		BaseURL:    baseURL,
		HTTPClient: &http.Client{Timeout: 45 * time.Second},
	}

	handler := &httpapi.Handler{
		ContentService: appcontent.Service{Generator: aiClient},
		AllowedOrigin:  allowedOrigin,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /content/generate", handler.GenerateContent)

	addr := fmt.Sprintf(":%s", port)
	log.Printf("ai listening on %s", addr)
	if err := http.ListenAndServe(addr, handler.CORS(mux)); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}

func getenv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func mustGetenv(key string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		log.Fatalf("missing required environment variable: %s", key)
	}
	return value
}

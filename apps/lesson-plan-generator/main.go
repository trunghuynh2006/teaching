package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/joho/godotenv"

	"lesson-plan-generator/internal/pipeline"
	"lesson-plan-generator/internal/transport/httpapi"
)

func main() {
	_ = godotenv.Load()

	port := getenv("PORT", "8200")
	allowedOrigin := getenv("ALLOWED_ORIGIN", "http://localhost:5173")
	apiKey := mustGetenv("OPENAI_API_KEY")
	voice := getenv("TTS_VOICE", "alloy")
	outputDir := getenv("OUTPUT_DIR", "output")

	handler := &httpapi.Handler{
		Generator:     pipeline.New(apiKey, voice, outputDir),
		AllowedOrigin: allowedOrigin,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /plans/{lesson_id}", handler.CreatePlan)

	addr := fmt.Sprintf(":%s", port)
	log.Printf("lesson-plan-generator listening on %s", addr)
	if err := http.ListenAndServe(addr, handler.CORS(mux)); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}

func getenv(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func mustGetenv(key string) string {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		log.Fatalf("missing required env var: %s", key)
	}
	return v
}

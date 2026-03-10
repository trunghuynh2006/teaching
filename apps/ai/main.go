package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	appcontent "ai/internal/app/content"
	"ai/internal/infra/ai/openai"
	"ai/internal/infra/cache/postgres"
	"ai/internal/infra/security"
	"ai/internal/prompts"
	"ai/internal/store"
	"ai/internal/transport/httpapi"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

	port := getenv("PORT", "8100")
	allowedOrigin := getenv("ALLOWED_ORIGIN", "http://localhost:5173")
	databaseURL := mustGetenv("DATABASE_URL")
	apiKey := mustGetenv("AI_API_KEY")
	model := getenv("AI_MODEL", "gpt-4o-mini")
	baseURL := strings.TrimSuffix(getenv("AI_BASE_URL", "https://api.openai.com/v1"), "/")
	cacheTTLSeconds := getenvInt("AI_PROMPT_CACHE_TTL_SECONDS", 900)
	cacheMaxEntries := getenvInt("AI_PROMPT_CACHE_MAX_ENTRIES", 512)
	jwtSecret := mustGetenv("JWT_SECRET")
	jwtAlgorithm := getenv("JWT_ALGORITHM", "HS256")
	ctx := context.Background()

	promptRegistry, err := prompts.New()
	if err != nil {
		log.Fatalf("failed to load prompt registry: %v", err)
	}

	db, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}
	defer db.Close()

	queries := store.New(db)
	if err := initCacheSchema(ctx, queries); err != nil {
		log.Fatalf("failed to initialize cache schema: %v", err)
	}

	aiClient := openai.NewOpenAIClient(apiKey, model, baseURL, promptRegistry)
	promptCache := postgres.NewPromptCache(queries, time.Duration(cacheTTLSeconds)*time.Second, cacheMaxEntries)

	handler := &httpapi.Handler{
		ContentService: appcontent.Service{
			Generator: aiClient,
			Cache:     promptCache,
		},
		JWT: security.JWT{
			Secret:    jwtSecret,
			Algorithm: jwtAlgorithm,
		},
		AllowedOrigin: allowedOrigin,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /content/lesson-titles", handler.Auth(handler.ListLessonTitles))
	mux.HandleFunc("POST /content/lesson", handler.Auth(handler.GenerateLesson))

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

func getenvInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func mustGetenv(key string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		log.Fatalf("missing required environment variable: %s", key)
	}
	return value
}

func initCacheSchema(ctx context.Context, queries *store.Queries) error {
	if err := queries.InitPromptCacheEntriesTable(ctx); err != nil {
		return err
	}
	if err := queries.InitPromptCacheEntriesExpiresAtIndex(ctx); err != nil {
		return err
	}
	return nil
}

package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	appauth "api2/internal/app/auth"
	"api2/internal/app/profile"
	"api2/internal/infra/persistence/postgres"
	"api2/internal/infra/security"
	"api2/internal/store"
	"api2/internal/transport/httpapi"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

type app struct {
	queries *store.Queries
	handler *httpapi.Handler
}

func main() {
	_ = godotenv.Load()

	databaseURL := mustGetenv("DATABASE_URL")
	jwtSecret := getenv("JWT_SECRET", "change_me_in_production")
	jwtAlgorithm := getenv("JWT_ALGORITHM", "HS256")
	jwtExpireMinutes := getenvInt("JWT_EXPIRE_MINUTES", 120)
	port := getenv("PORT", "8000")

	ctx := context.Background()
	db, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}
	defer db.Close()

	queries := store.New(db)
	userRepo := postgres.UserRepository{Queries: queries}
	authService := appauth.Service{
		Users:    userRepo,
		Password: security.Bcrypt{},
		Tokens: security.JWT{
			Secret:        jwtSecret,
			Algorithm:     jwtAlgorithm,
			ExpireMinutes: jwtExpireMinutes,
		},
	}

	handler := &httpapi.Handler{
		AuthService:    authService,
		ProfileService: profile.Service{},
		Queries:        queries,
		AllowedOrigin:  "http://localhost:5173",
		UploadDir:      getenv("UPLOAD_DIR", "./uploads"),
	}

	application := &app{
		queries: queries,
		handler: handler,
	}

	if err := application.initDB(ctx); err != nil {
		log.Fatalf("failed to initialize db: %v", err)
	}
	if len(os.Args) > 1 && os.Args[1] == "seed-users" {
		if err := application.seedUsers(ctx); err != nil {
			log.Fatalf("failed to seed users: %v", err)
		}
		log.Println("seeded demo users")
		return
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /auth/login", handler.Login)
	mux.HandleFunc("GET /me", handler.Auth(handler.Me))
	mux.HandleFunc("GET /role/", handler.Auth(handler.RoleData))
	mux.HandleFunc("GET /skills", handler.Auth(handler.ListSkills))
	mux.HandleFunc("GET /skills/{id}", handler.Auth(handler.GetSkill))
	mux.HandleFunc("POST /skills", handler.Auth(handler.CreateSkill))
	mux.HandleFunc("PUT /skills/{id}", handler.Auth(handler.UpdateSkill))
	mux.HandleFunc("POST /skills/{id}/publish", handler.Auth(handler.PublishSkill))
	mux.HandleFunc("POST /skills/{id}/archive", handler.Auth(handler.ArchiveSkill))
	mux.HandleFunc("POST /skills/{id}/draft", handler.Auth(handler.MoveSkillToDraft))
	mux.HandleFunc("POST /recordings/sessions", handler.Auth(handler.CreateRecordingSession))
	mux.HandleFunc("POST /recordings/sessions/{id}/chunks", handler.Auth(handler.UploadChunk))
	mux.HandleFunc("POST /recordings/sessions/{id}/finalize", handler.Auth(handler.FinalizeRecording))

	wrapped := handler.CORS(mux)
	addr := fmt.Sprintf(":%s", port)
	log.Printf("api2 listening on %s", addr)
	if err := http.ListenAndServe(addr, wrapped); err != nil {
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

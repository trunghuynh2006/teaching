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
	infra_ai "api2/internal/infra/ai"
	"api2/internal/infra/persistence/postgres"
	"api2/internal/infra/security"
	"api2/internal/infra/wiki"
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
		OpenAIKey:      getenv("OPENAI_API_KEY", ""),
		AIClient:       &infra_ai.Client{BaseURL: getenv("AI_SERVICE_URL", "http://localhost:8100")},
		WikiClient:     &wiki.Client{BaseURL: getenv("WIKI_SERVICE_URL", "http://localhost:8200")},
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
	if len(os.Args) > 2 && os.Args[1] == "seed-concepts" {
		domains := os.Args[2:]
		if err := application.seedDomainConcepts(ctx, domains); err != nil {
			log.Fatalf("failed to seed concepts: %v", err)
		}
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
	mux.HandleFunc("GET /audio-records", handler.Auth(handler.ListAudioRecords))
	mux.HandleFunc("GET /folders", handler.Auth(handler.ListFolders))
	mux.HandleFunc("POST /folders", handler.Auth(handler.CreateFolder))
	mux.HandleFunc("GET /folders/{id}", handler.Auth(handler.GetFolder))
	mux.HandleFunc("PUT /folders/{id}", handler.Auth(handler.UpdateFolder))
	mux.HandleFunc("DELETE /folders/{id}", handler.Auth(handler.DeleteFolder))
	mux.HandleFunc("GET /folders/{id}/skills", handler.Auth(handler.ListFolderSkills))
	mux.HandleFunc("POST /folders/{id}/skills/{skill_id}", handler.Auth(handler.AddSkillToFolder))
	mux.HandleFunc("DELETE /folders/{id}/skills/{skill_id}", handler.Auth(handler.RemoveSkillFromFolder))
	mux.HandleFunc("GET /folders/{id}/members", handler.Auth(handler.ListFolderMembers))
	mux.HandleFunc("POST /folders/{id}/members", handler.Auth(handler.AddFolderMember))
	mux.HandleFunc("DELETE /folders/{id}/members/{user_id}", handler.Auth(handler.RemoveFolderMember))
	mux.HandleFunc("GET /folders/{id}/topics", handler.Auth(handler.ListFolderTopics))
	mux.HandleFunc("POST /folders/{id}/topics", handler.Auth(handler.CreateTopic))
	mux.HandleFunc("PUT /topics/{id}", handler.Auth(handler.UpdateTopic))
	mux.HandleFunc("DELETE /topics/{id}", handler.Auth(handler.DeleteTopic))
	mux.HandleFunc("GET /wiki/concepts/search", handler.Auth(handler.SearchWikiConcepts))
	mux.HandleFunc("GET /wiki/concepts/by-domain", handler.Auth(handler.GetWikiConceptsByDomain))
	mux.HandleFunc("POST /sources/fetch-url", handler.Auth(handler.FetchURLContent))
	mux.HandleFunc("POST /sources/{id}/generate-concepts", handler.Auth(handler.GenerateSourceConcepts))
	mux.HandleFunc("GET /folders/{id}/sources", handler.Auth(handler.ListFolderSources))
	mux.HandleFunc("POST /folders/{id}/sources", handler.Auth(handler.CreateSource))
	mux.HandleFunc("POST /folders/{id}/sources/upload-pdf", handler.Auth(handler.UploadPDFSource))
	mux.HandleFunc("GET /sources/{id}", handler.Auth(handler.GetSource))
	mux.HandleFunc("PUT /sources/{id}", handler.Auth(handler.UpdateSource))
	mux.HandleFunc("DELETE /sources/{id}", handler.Auth(handler.DeleteSource))
	mux.HandleFunc("GET /sources/{id}/concepts", handler.Auth(handler.ListSourceConcepts))
	mux.HandleFunc("POST /sources/{id}/concepts", handler.Auth(handler.LinkSourceConcept))
	mux.HandleFunc("DELETE /sources/{id}/concepts/{concept_id}", handler.Auth(handler.UnlinkSourceConcept))
	mux.HandleFunc("GET /topics/{id}/concepts", handler.Auth(handler.ListTopicConcepts))
	mux.HandleFunc("POST /topics/{id}/concepts", handler.Auth(handler.LinkTopicConcept))
	mux.HandleFunc("DELETE /topics/{id}/concepts/{concept_id}", handler.Auth(handler.UnlinkTopicConcept))
	mux.HandleFunc("GET /concepts", handler.Auth(handler.ListConcepts))
	mux.HandleFunc("POST /concepts", handler.Auth(handler.CreateConcept))
	mux.HandleFunc("POST /concepts/seed-domain", handler.Auth(handler.SeedDomainConcepts))
	mux.HandleFunc("POST /concepts/{id}/generate-materials", handler.Auth(handler.GenerateConceptMaterials))
	mux.HandleFunc("GET /concepts/{id}", handler.Auth(handler.GetConcept))
	mux.HandleFunc("PUT /concepts/{id}", handler.Auth(handler.UpdateConcept))
	mux.HandleFunc("DELETE /concepts/{id}", handler.Auth(handler.DeleteConcept))
	mux.HandleFunc("GET /concepts/{id}/prerequisites", handler.Auth(handler.ListConceptPrerequisites))
	mux.HandleFunc("POST /concepts/{id}/prerequisites", handler.Auth(handler.AddConceptPrerequisite))
	mux.HandleFunc("DELETE /concepts/{id}/prerequisites/{prerequisite_id}", handler.Auth(handler.RemoveConceptPrerequisite))
	mux.HandleFunc("GET /folders/{id}/spaces", handler.Auth(handler.ListFolderSpaces))
	mux.HandleFunc("POST /folders/{id}/spaces", handler.Auth(handler.CreateSpace))
	mux.HandleFunc("GET /spaces/{id}", handler.Auth(handler.GetSpace))
	mux.HandleFunc("PUT /spaces/{id}", handler.Auth(handler.UpdateSpace))
	mux.HandleFunc("DELETE /spaces/{id}", handler.Auth(handler.DeleteSpace))
	mux.HandleFunc("GET /spaces/{id}/questions", handler.Auth(handler.ListSpaceQuestions))
	mux.HandleFunc("POST /spaces/{id}/questions", handler.Auth(handler.CreateQuestion))
	mux.HandleFunc("GET /questions/{id}", handler.Auth(handler.GetQuestion))
	mux.HandleFunc("PUT /questions/{id}", handler.Auth(handler.UpdateQuestion))
	mux.HandleFunc("DELETE /questions/{id}", handler.Auth(handler.DeleteQuestion))
	mux.HandleFunc("POST /questions/{id}/answers", handler.Auth(handler.CreateAnswer))
	mux.HandleFunc("PUT /answers/{id}", handler.Auth(handler.UpdateAnswer))
	mux.HandleFunc("DELETE /answers/{id}", handler.Auth(handler.DeleteAnswer))
	mux.HandleFunc("GET /spaces/{id}/problems", handler.Auth(handler.ListSpaceProblems))
	mux.HandleFunc("POST /spaces/{id}/problems", handler.Auth(handler.CreateProblem))
	mux.HandleFunc("GET /problems/{id}", handler.Auth(handler.GetProblem))
	mux.HandleFunc("PUT /problems/{id}", handler.Auth(handler.UpdateProblem))
	mux.HandleFunc("DELETE /problems/{id}", handler.Auth(handler.DeleteProblem))
	mux.HandleFunc("POST /problems/{id}/steps", handler.Auth(handler.CreateProblemStep))
	mux.HandleFunc("PUT /problem-steps/{id}", handler.Auth(handler.UpdateProblemStep))
	mux.HandleFunc("DELETE /problem-steps/{id}", handler.Auth(handler.DeleteProblemStep))
	mux.HandleFunc("POST /spaces/{id}/generate-questions", handler.Auth(handler.GenerateQuestionsForSpace))
	mux.HandleFunc("POST /spaces/{id}/generate-flash-cards", handler.Auth(handler.GenerateFlashCardsForSpace))
	mux.HandleFunc("GET /spaces/{id}/flash-cards", handler.Auth(handler.ListSpaceFlashCards))
	mux.HandleFunc("GET /spaces/{id}/flash-cards/due", handler.Auth(handler.ListSpaceFlashCardsDue))
	mux.HandleFunc("POST /spaces/{id}/flash-cards", handler.Auth(handler.CreateFlashCard))
	mux.HandleFunc("GET /flash-cards/{id}", handler.Auth(handler.GetFlashCard))
	mux.HandleFunc("PUT /flash-cards/{id}", handler.Auth(handler.UpdateFlashCard))
	mux.HandleFunc("DELETE /flash-cards/{id}", handler.Auth(handler.DeleteFlashCard))
	mux.HandleFunc("POST /flash-cards/{id}/review", handler.Auth(handler.ReviewFlashCard))
	mux.HandleFunc("GET /domains", handler.Auth(handler.ListDomains))
	mux.HandleFunc("POST /domains", handler.Auth(handler.CreateDomain))
	mux.HandleFunc("GET /domains/{id}", handler.Auth(handler.GetDomain))
	mux.HandleFunc("PUT /domains/{id}", handler.Auth(handler.UpdateDomain))
	mux.HandleFunc("DELETE /domains/{id}", handler.Auth(handler.DeleteDomain))
	mux.HandleFunc("POST /domains/{id}/parents", handler.Auth(handler.AddDomainParent))
	mux.HandleFunc("DELETE /domains/{id}/parents/{parent}", handler.Auth(handler.RemoveDomainParent))
	mux.HandleFunc("POST /domains/{id}/discover-parents", handler.Auth(handler.DiscoverDomainParents))
	mux.HandleFunc("POST /domains/{id}/generate-concepts", handler.Auth(handler.GenerateDomainConcepts))

	mux.HandleFunc("GET /learning-paths", handler.Auth(handler.ListLearningPaths))
	mux.HandleFunc("POST /learning-paths", handler.Auth(handler.CreateLearningPath))
	mux.HandleFunc("GET /learning-paths/{id}", handler.Auth(handler.GetLearningPath))
	mux.HandleFunc("PUT /learning-paths/{id}", handler.Auth(handler.UpdateLearningPath))
	mux.HandleFunc("DELETE /learning-paths/{id}", handler.Auth(handler.DeleteLearningPath))
	mux.HandleFunc("GET /learning-paths/{id}/steps", handler.Auth(handler.ListLearningPathSteps))
	mux.HandleFunc("POST /learning-paths/{id}/steps", handler.Auth(handler.AddLearningPathStep))
	mux.HandleFunc("DELETE /learning-paths/{id}/steps/{concept_id}", handler.Auth(handler.RemoveLearningPathStep))
	mux.HandleFunc("PATCH /learning-paths/{id}/steps/{concept_id}", handler.Auth(handler.ReorderLearningPathStep))
	mux.HandleFunc("POST /questions/{id}/attempt", handler.Auth(handler.RecordQuestionAttempt))
	mux.HandleFunc("GET /spaces/{id}/my-attempts", handler.Auth(handler.ListMySpaceAttempts))
	mux.HandleFunc("GET /spaces/{id}/attempts/stats", handler.Auth(handler.ListSpaceAttemptStats))

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

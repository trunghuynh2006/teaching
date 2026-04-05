package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"wikiprovider/internal/handler"

	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

	port := getenv("PORT", "8200")
	cacheDir := getenv("CACHE_DIR", "/home/trung/Documents/.teachingdata/wikiprovider")
	cacheTTLHours := getenvDuration("CACHE_TTL_HOURS", 24*time.Hour)

	h, err := handler.New(cacheDir, cacheTTLHours)
	if err != nil {
		log.Fatalf("failed to initialise handler: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", h.Health)
	mux.HandleFunc("GET /concepts/search", h.SearchConcepts)
	mux.HandleFunc("GET /concepts/by-domain", h.GetConceptsByDomain)
	mux.HandleFunc("GET /concepts/{qid}", h.GetConceptByQID)

	addr := fmt.Sprintf(":%s", port)
	log.Printf("wikiprovider listening on %s (cache: %s, ttl: %s)", addr, cacheDir, cacheTTLHours)
	if err := http.ListenAndServe(addr, handler.InboundRateLimit(mux)); err != nil {
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

func getenvDuration(key string, fallback time.Duration) time.Duration {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	hours, err := time.ParseDuration(value + "h")
	if err != nil {
		return fallback
	}
	return hours
}

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
	cacheTTL := getenvDuration("CACHE_TTL_HOURS", 24*time.Hour)

	h, err := handler.New(cacheDir, cacheTTL)
	if err != nil {
		log.Fatalf("failed to initialise handler: %v", err)
	}

	// Subcommand: cache by-domain <domain> [domain2 ...]
	if len(os.Args) >= 3 && os.Args[1] == "cache" && os.Args[2] == "by-domain" {
		domains := os.Args[3:]
		if len(domains) == 0 {
			log.Fatal("usage: wikiprovider cache by-domain <domain> [domain2 ...]")
		}
		runPrecache(h, domains)
		return
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", h.Health)
	mux.HandleFunc("GET /concepts/search", h.SearchConcepts)
	mux.HandleFunc("GET /concepts/by-domain", h.GetConceptsByDomain)
	mux.HandleFunc("GET /concepts/{qid}", h.GetConceptByQID)

	addr := fmt.Sprintf(":%s", port)
	log.Printf("wikiprovider listening on %s (cache: %s, ttl: %s)", addr, cacheDir, cacheTTL)
	if err := http.ListenAndServe(addr, handler.InboundRateLimit(mux)); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}

func runPrecache(h *handler.Handler, domains []string) {
	for _, domain := range domains {
		log.Printf("caching domain: %s …", domain)
		results, err := h.FetchConceptsByDomain(domain, 0)
		if err != nil {
			log.Printf("  ERROR: %v", err)
			continue
		}
		log.Printf("  cached %d concepts", len(results))
		// Wikidata rate limit: wait between requests
		if len(domains) > 1 {
			time.Sleep(600 * time.Millisecond)
		}
	}
	log.Println("pre-cache complete")
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

package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"wikiprovider/internal/handler"

	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

	port := getenv("PORT", "8200")

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("GET /concepts/search", handler.SearchConcepts)
	mux.HandleFunc("GET /concepts/by-domain", handler.GetConceptsByDomain)
	mux.HandleFunc("GET /concepts/{qid}", handler.GetConceptByQID)

	addr := fmt.Sprintf(":%s", port)
	log.Printf("wikiprovider listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
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

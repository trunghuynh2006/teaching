package main

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	infra_ai "api2/internal/infra/ai"
	"api2/internal/store"
	"api2/internal/transport/httpapi"
)

// seedDomainConcepts calls the AI service to generate foundation concepts for each
// domain and persists them, skipping any that already exist by canonical name.
func (a *app) seedDomainConcepts(ctx context.Context, domains []string) error {
	if a.handler.AIClient == nil {
		return fmt.Errorf("AI service not configured (AI_SERVICE_URL / AI_API_KEY missing)")
	}

	serviceToken, err := a.handler.AuthService.Tokens.CreateAccessToken("api2-service", "teacher")
	if err != nil {
		return fmt.Errorf("mint service token: %w", err)
	}

	for _, domain := range domains {
		domain = strings.TrimSpace(domain)
		if domain == "" {
			continue
		}
		log.Printf("seeding domain: %q …", domain)

		callCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
		generated, err := a.handler.AIClient.SeedFoundationConcepts(callCtx, serviceToken,
			infra_ai.SeedFoundationConceptsRequest{Domain: domain})
		cancel()
		if err != nil {
			log.Printf("  ERROR generating concepts for %q: %v", domain, err)
			continue
		}

		// Dedup against existing concepts in this domain
		existing, _ := a.queries.ListConceptsByDomain(ctx, domain)
		existingNames := make(map[string]bool, len(existing))
		for _, c := range existing {
			existingNames[strings.ToLower(c.CanonicalName)] = true
		}

		created := 0
		skipped := 0
		for _, gc := range generated {
			if existingNames[strings.ToLower(gc.CanonicalName)] {
				skipped++
				continue
			}
			_, err := a.queries.CreateConcept(ctx, store.CreateConceptParams{
				ID:            httpapi.NewConceptIDExported(),
				CanonicalName: gc.CanonicalName,
				Domain:        domain,
				Description:   gc.Description,
				Tags:          gc.Tags,
				Level:         gc.Level,
				Scope:         gc.Scope,
				CreatedBy:     "seed",
				UpdatedBy:     "seed",
			})
			if err != nil {
				log.Printf("  WARN: could not save %q: %v", gc.CanonicalName, err)
				continue
			}
			created++
		}
		log.Printf("  done — %d created, %d already existed", created, skipped)
	}
	return nil
}

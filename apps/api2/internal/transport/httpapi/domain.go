package httpapi

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"api2/internal/domain/user"
	infra_ai "api2/internal/infra/ai"
	"api2/internal/store"

	"github.com/jackc/pgx/v5"
)

// ── Domain response ───────────────────────────────────────────────────────────

type domainResponse struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description,omitempty"`
	CreatedBy   string   `json:"created_by,omitempty"`
	CreatedTime string   `json:"created_time,omitempty"`
	UpdatedTime string   `json:"updated_time,omitempty"`
	Parents     []string `json:"parents,omitempty"`
	Children    []string `json:"children,omitempty"`
}

func toDomainResponse(d store.Domain) domainResponse {
	r := domainResponse{
		ID:          d.ID,
		Name:        d.Name,
		Description: d.Description,
		CreatedBy:   d.CreatedBy,
	}
	if d.CreatedTime.Valid {
		r.CreatedTime = d.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
	}
	if d.UpdatedTime.Valid {
		r.UpdatedTime = d.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
	}
	return r
}

func newDomainID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return "dom_" + hex.EncodeToString(b)
}

// ── CRUD ──────────────────────────────────────────────────────────────────────

func (h *Handler) ListDomains(w http.ResponseWriter, r *http.Request, _ user.User) {
	domains, err := h.Queries.ListDomains(r.Context())
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to list domains"})
		return
	}

	// Load all prerequisite rows once and build a lookup map.
	prereqs, err := h.Queries.ListAllDomainPrerequisites(r.Context())
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to list domain relationships"})
		return
	}
	parents := map[string][]string{}   // domain -> parent names
	children := map[string][]string{}  // domain -> child names
	for _, p := range prereqs {
		parents[p.Domain] = append(parents[p.Domain], p.Prerequisite)
		children[p.Prerequisite] = append(children[p.Prerequisite], p.Domain)
	}

	out := make([]domainResponse, 0, len(domains))
	for _, d := range domains {
		resp := toDomainResponse(d)
		resp.Parents = parents[d.Name]
		resp.Children = children[d.Name]
		if resp.Parents == nil {
			resp.Parents = []string{}
		}
		if resp.Children == nil {
			resp.Children = []string{}
		}
		out = append(out, resp)
	}
	writeJSON(w, http.StatusOK, map[string]any{"domains": out})
}

func (h *Handler) CreateDomain(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	var body struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || strings.TrimSpace(body.Name) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "name is required"})
		return
	}
	d, err := h.Queries.CreateDomain(r.Context(), store.CreateDomainParams{
		ID:          newDomainID(),
		Name:        strings.TrimSpace(body.Name),
		Description: strings.TrimSpace(body.Description),
		CreatedBy:   currentUser.Username,
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		if strings.Contains(err.Error(), "uq_domains_name") {
			writeJSON(w, http.StatusConflict, ErrorResponse{Detail: "domain already exists"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to create domain"})
		return
	}
	resp := toDomainResponse(d)
	resp.Parents = []string{}
	resp.Children = []string{}
	writeJSON(w, http.StatusCreated, resp)
}

func (h *Handler) GetDomain(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	d, err := h.Queries.GetDomainByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "domain not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to get domain"})
		return
	}
	resp := toDomainResponse(d)
	parents, _ := h.Queries.ListDomainParents(r.Context(), d.Name)
	children, _ := h.Queries.ListDomainChildren(r.Context(), d.Name)
	if parents == nil {
		parents = []string{}
	}
	if children == nil {
		children = []string{}
	}
	resp.Parents = parents
	resp.Children = children
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) UpdateDomain(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	var body struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || strings.TrimSpace(body.Name) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "name is required"})
		return
	}
	d, err := h.Queries.UpdateDomain(r.Context(), store.UpdateDomainParams{
		ID:          id,
		Name:        strings.TrimSpace(body.Name),
		Description: strings.TrimSpace(body.Description),
		UpdatedBy:   currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "domain not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to update domain"})
		return
	}
	resp := toDomainResponse(d)
	parents, _ := h.Queries.ListDomainParents(r.Context(), d.Name)
	children, _ := h.Queries.ListDomainChildren(r.Context(), d.Name)
	if parents == nil {
		parents = []string{}
	}
	if children == nil {
		children = []string{}
	}
	resp.Parents = parents
	resp.Children = children
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) DeleteDomain(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if err := h.Queries.DeleteDomain(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to delete domain"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Parent management ─────────────────────────────────────────────────────────

func (h *Handler) AddDomainParent(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	d, err := h.Queries.GetDomainByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "domain not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to get domain"})
		return
	}
	var body struct {
		Parent string `json:"parent"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || strings.TrimSpace(body.Parent) == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "parent is required"})
		return
	}
	if err := h.Queries.AddDomainPrerequisite(r.Context(), d.Name, strings.TrimSpace(body.Parent), currentUser.Username); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to add parent"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) RemoveDomainParent(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	parent := strings.TrimSpace(r.PathValue("parent"))
	d, err := h.Queries.GetDomainByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "domain not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to get domain"})
		return
	}
	if err := h.Queries.RemoveDomainPrerequisite(r.Context(), d.Name, parent); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to remove parent"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── AI: discover parent domains ───────────────────────────────────────────────

func (h *Handler) DiscoverDomainParents(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	d, err := h.Queries.GetDomainByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "domain not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to get domain"})
		return
	}

	serviceToken, err := h.AuthService.Tokens.CreateAccessToken("api2-service", "teacher")
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to create service token"})
		return
	}

	parentDomains, err := h.AIClient.DiscoverParentDomains(r.Context(), serviceToken, infra_ai.DiscoverParentDomainsRequest{
		Domain: d.Name,
	})
	if err != nil {
		log.Printf("discover domain parents error: %v", err)
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: "failed to discover parent domains"})
		return
	}

	// For each discovered parent: ensure a Domain row exists, then link it.
	for _, parentName := range parentDomains {
		// Look up by name; create if missing.
		if _, err := h.Queries.GetDomainByName(r.Context(), parentName); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				if _, createErr := h.Queries.CreateDomain(r.Context(), store.CreateDomainParams{
					ID:        newDomainID(),
					Name:      parentName,
					CreatedBy: currentUser.Username,
					UpdatedBy: currentUser.Username,
				}); createErr != nil {
					log.Printf("create parent domain %q: %v", parentName, createErr)
				}
			} else {
				log.Printf("get parent domain %q: %v", parentName, err)
			}
		}
		if err := h.Queries.AddDomainPrerequisite(r.Context(), d.Name, parentName, currentUser.Username); err != nil {
			log.Printf("add domain prerequisite %q -> %q: %v", d.Name, parentName, err)
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{"parent_domains": parentDomains})
}

// ── AI: generate concepts for domain ─────────────────────────────────────────

func (h *Handler) GenerateDomainConcepts(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	d, err := h.Queries.GetDomainByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "domain not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to get domain"})
		return
	}

	serviceToken, err := h.AuthService.Tokens.CreateAccessToken("api2-service", "teacher")
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "failed to create service token"})
		return
	}

	// Step 1: seed foundation concepts for this domain.
	seeded, err := h.AIClient.SeedFoundationConcepts(r.Context(), serviceToken, infra_ai.SeedFoundationConceptsRequest{
		Domain: d.Name,
	})
	if err != nil {
		log.Printf("generate domain concepts seed error: %v", err)
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: "failed to generate concepts"})
		return
	}

	// Persist concepts (dedup by canonical_name + domain).
	existing, _ := h.Queries.ListConceptsByDomain(r.Context(), d.Name)
	existingNames := map[string]bool{}
	for _, c := range existing {
		existingNames[strings.ToLower(c.CanonicalName)] = true
	}

	created := make([]conceptResponse, 0, len(seeded))
	for _, sc := range seeded {
		if existingNames[strings.ToLower(sc.CanonicalName)] {
			continue
		}
		c, err := h.Queries.CreateConcept(r.Context(), store.CreateConceptParams{
			ID:             newConceptID(),
			CanonicalName:  sc.CanonicalName,
			Domain:         d.Name,
			Description:    sc.Description,
			Example:        sc.Example,
			Analogy:        sc.Analogy,
			CommonMistakes: sc.CommonMistakes,
			Tags:           sc.Tags,
			Level:         sc.Level,
			Scope:         sc.Scope,
			CreatedBy:     currentUser.Username,
			UpdatedBy:     currentUser.Username,
		})
		if err != nil {
			log.Printf("create concept %q: %v", sc.CanonicalName, err)
			continue
		}
		existingNames[strings.ToLower(sc.CanonicalName)] = true
		created = append(created, toConceptResponse(c))
	}

	// Step 2 (Option B): post-seed LLM call to match child concepts -> parent domain concepts.
	parentDomainNames, _ := h.Queries.ListDomainParents(r.Context(), d.Name)
	if len(parentDomainNames) > 0 && len(created) > 0 {
		h.runPostSeedParentMatching(r.Context(), serviceToken, d.Name, created, parentDomainNames, currentUser.Username)
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"created": created,
		"total":   len(created),
	})
}

// runPostSeedParentMatching runs the Option B LLM call to link child concepts to parent concepts.
// Errors are logged but do not fail the request — concept seeding already succeeded.
func (h *Handler) runPostSeedParentMatching(
	ctx context.Context,
	serviceToken string,
	childDomain string,
	childConcepts []conceptResponse,
	parentDomainNames []string,
	createdBy string,
) {
	// Gather all existing concepts from parent domains.
	var parentConceptNames []string
	for _, pDomain := range parentDomainNames {
		pConcepts, err := h.Queries.ListConceptsByDomain(ctx, pDomain)
		if err != nil {
			continue
		}
		for _, pc := range pConcepts {
			parentConceptNames = append(parentConceptNames, pc.CanonicalName)
		}
	}
	if len(parentConceptNames) == 0 {
		return
	}

	childNames := make([]string, 0, len(childConcepts))
	for _, c := range childConcepts {
		childNames = append(childNames, c.CanonicalName)
	}

	matches, err := h.AIClient.MatchParentConcepts(ctx, serviceToken, infra_ai.MatchParentConceptsRequest{
		Domain:         childDomain,
		ChildConcepts:  childNames,
		ParentDomains:  parentDomainNames,
		ParentConcepts: parentConceptNames,
	})
	if err != nil {
		log.Printf("match parent concepts error: %v", err)
		return
	}

	// Build a lookup: parent concept name -> concept ID.
	parentConceptByName := map[string]string{}
	for _, pDomain := range parentDomainNames {
		pConcepts, err := h.Queries.ListConceptsByDomain(ctx, pDomain)
		if err != nil {
			continue
		}
		for _, pc := range pConcepts {
			parentConceptByName[strings.ToLower(pc.CanonicalName)] = pc.ID
		}
	}

	// Build lookup: child concept name -> concept ID.
	childByName := map[string]string{}
	for _, c := range childConcepts {
		childByName[strings.ToLower(c.CanonicalName)] = c.ID
	}

	for _, m := range matches {
		childID, ok := childByName[strings.ToLower(m.ChildConcept)]
		if !ok {
			continue
		}
		parentID, ok := parentConceptByName[strings.ToLower(m.ParentConcept)]
		if !ok {
			continue
		}
		// Get the child concept and update its parent_concept_id.
		child, err := h.Queries.GetConceptByID(ctx, childID)
		if err != nil {
			log.Printf("get child concept %q: %v", childID, err)
			continue
		}
		if child.ParentConceptID != "" {
			continue // already linked
		}
		_, err = h.Queries.UpdateConcept(ctx, store.UpdateConceptParams{
			ID:              childID,
			CanonicalName:   child.CanonicalName,
			Domain:          child.Domain,
			Description:     child.Description,
			Tags:            child.Tags,
			Level:           child.Level,
			Scope:           child.Scope,
			ParentConceptID: parentID,
			UpdatedBy:       createdBy,
		})
		if err != nil {
			log.Printf("set parent concept %q -> %q: %v", childID, parentID, err)
		}
	}
}

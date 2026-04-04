package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const wikidataSPARQL = "https://query.wikidata.org/sparql"

var httpClient = &http.Client{Timeout: 15 * time.Second}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

type errorResponse struct {
	Detail string `json:"detail"`
}

// SearchConcepts handles GET /concepts/search?q=...&limit=...
// Returns concepts matching the query from Wikidata.
func SearchConcepts(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Detail: "q is required"})
		return
	}
	limit := r.URL.Query().Get("limit")
	if limit == "" {
		limit = "20"
	}

	sparql := fmt.Sprintf(`
SELECT DISTINCT ?item ?itemLabel ?itemDescription WHERE {
  ?item wikibase:directClaim ?p .
  ?item rdfs:label ?itemLabel .
  FILTER(LANG(?itemLabel) = "en")
  FILTER(CONTAINS(LCASE(?itemLabel), LCASE("%s")))
  OPTIONAL { ?item schema:description ?itemDescription . FILTER(LANG(?itemDescription) = "en") }
} LIMIT %s`, escapeString(q), limit)

	results, err := runSPARQL(sparql)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, errorResponse{Detail: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, results)
}

// GetConceptsByDomain handles GET /concepts/by-domain?domain=...&limit=...
// Returns foundational concepts for a given domain using Wikidata subclass graph.
func GetConceptsByDomain(w http.ResponseWriter, r *http.Request) {
	domain := strings.TrimSpace(r.URL.Query().Get("domain"))
	if domain == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Detail: "domain is required"})
		return
	}
	limit := r.URL.Query().Get("limit")
	if limit == "" {
		limit = "50"
	}

	// First resolve the domain label to a QID, then find subclass concepts
	sparql := fmt.Sprintf(`
SELECT DISTINCT ?item ?itemLabel ?itemDescription WHERE {
  ?domain rdfs:label "%s"@en .
  ?item wdt:P279* ?domain .
  ?item rdfs:label ?itemLabel .
  FILTER(LANG(?itemLabel) = "en")
  OPTIONAL { ?item schema:description ?itemDescription . FILTER(LANG(?itemDescription) = "en") }
} LIMIT %s`, escapeString(domain), limit)

	results, err := runSPARQL(sparql)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, errorResponse{Detail: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, results)
}

// GetConceptByQID handles GET /concepts/{qid}
// Returns a single Wikidata item with its label, description, and subclass-of links.
func GetConceptByQID(w http.ResponseWriter, r *http.Request) {
	qid := strings.TrimSpace(r.PathValue("qid"))
	if qid == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Detail: "qid is required"})
		return
	}

	sparql := fmt.Sprintf(`
SELECT ?item ?itemLabel ?itemDescription ?parent ?parentLabel WHERE {
  BIND(wd:%s AS ?item)
  ?item rdfs:label ?itemLabel . FILTER(LANG(?itemLabel) = "en")
  OPTIONAL { ?item schema:description ?itemDescription . FILTER(LANG(?itemDescription) = "en") }
  OPTIONAL { ?item wdt:P279 ?parent . ?parent rdfs:label ?parentLabel . FILTER(LANG(?parentLabel) = "en") }
}`, escapeString(qid))

	results, err := runSPARQL(sparql)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, errorResponse{Detail: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, results)
}

// Health handles GET /health
func Health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ─── SPARQL helpers ──────────────────────────────────────────────────────────

type SPARQLResult struct {
	QID         string `json:"qid"`
	Label       string `json:"label"`
	Description string `json:"description,omitempty"`
	ParentQID   string `json:"parent_qid,omitempty"`
	ParentLabel string `json:"parent_label,omitempty"`
}

func runSPARQL(query string) ([]SPARQLResult, error) {
	req, err := http.NewRequest(http.MethodGet, wikidataSPARQL, nil)
	if err != nil {
		return nil, err
	}
	params := url.Values{}
	params.Set("query", query)
	params.Set("format", "json")
	req.URL.RawQuery = params.Encode()
	req.Header.Set("Accept", "application/sparql-results+json")
	req.Header.Set("User-Agent", "T2T-WikiProvider/1.0 (teaching platform)")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("wikidata request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("wikidata returned %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var raw struct {
		Results struct {
			Bindings []map[string]struct {
				Type  string `json:"type"`
				Value string `json:"value"`
			} `json:"bindings"`
		} `json:"results"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return nil, fmt.Errorf("parse wikidata response: %w", err)
	}

	seen := map[string]bool{}
	var out []SPARQLResult
	for _, b := range raw.Results.Bindings {
		itemURI := b["item"].Value
		qid := qidFromURI(itemURI)
		if seen[qid] {
			continue
		}
		seen[qid] = true
		r := SPARQLResult{
			QID:         qid,
			Label:       b["itemLabel"].Value,
			Description: b["itemDescription"].Value,
		}
		if p, ok := b["parent"]; ok {
			r.ParentQID = qidFromURI(p.Value)
			r.ParentLabel = b["parentLabel"].Value
		}
		out = append(out, r)
	}
	return out, nil
}

func qidFromURI(uri string) string {
	parts := strings.Split(uri, "/")
	return parts[len(parts)-1]
}

func escapeString(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	return s
}

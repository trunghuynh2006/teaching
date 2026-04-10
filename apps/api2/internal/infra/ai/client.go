// Package ai provides an HTTP client for calling the internal ai service.
package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Client calls the internal ai service.
type Client struct {
	BaseURL    string
	HTTPClient *http.Client
}

// GeneratedCard is one card returned by the ai service.
type GeneratedCard struct {
	FrontText  string   `json:"front_text"`
	BackText   string   `json:"back_text"`
	BloomLevel string   `json:"bloom_level"`
	Tags       []string `json:"tags,omitempty"`
}

// ExtractConceptsRequest mirrors the ai service POST /content/concepts body.
type ExtractConceptsRequest struct {
	SourceText string `json:"source_text"`
	Language   string `json:"language"`
	Domain     string `json:"domain,omitempty"`
}

// ExtractedConcept is one concept returned by the ai service.
type ExtractedConcept struct {
	CanonicalName string   `json:"canonical_name"`
	Description   string   `json:"description"`
	Domain        string   `json:"domain,omitempty"`
	Tags          []string `json:"tags,omitempty"`
}

// ExtractConcepts calls POST /content/concepts on the ai service.
func (c *Client) ExtractConcepts(ctx context.Context, bearerToken string, req ExtractConceptsRequest) ([]ExtractedConcept, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 60 * time.Second}
	}

	url := strings.TrimSuffix(c.BaseURL, "/") + "/content/concepts"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+bearerToken)

	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai service unavailable: %w", err)
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode >= http.StatusBadRequest {
		var errBody struct {
			Detail string `json:"detail"`
		}
		if jsonErr := json.Unmarshal(rawBody, &errBody); jsonErr == nil && errBody.Detail != "" {
			return nil, fmt.Errorf("ai service error: %s", errBody.Detail)
		}
		return nil, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}

	var result struct {
		Concepts []ExtractedConcept `json:"concepts"`
	}
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return nil, fmt.Errorf("ai service: parse response: %w", err)
	}
	return result.Concepts, nil
}

// GeneratedMCAnswer is one answer choice returned by the ai service.
type GeneratedMCAnswer struct {
	Text      string `json:"text"`
	IsCorrect bool   `json:"is_correct"`
}

// GeneratedMCQuestion is one multiple-choice question returned by the ai service.
type GeneratedMCQuestion struct {
	Body    string              `json:"body"`
	Answers []GeneratedMCAnswer `json:"answers"`
}

// GenerateMCQuestionsRequest mirrors the ai service POST /content/mc-questions body.
type GenerateMCQuestionsRequest struct {
	SourceText string `json:"source_text"`
	Language   string `json:"language"`
}

// GenerateMCQuestions calls POST /content/mc-questions on the ai service.
func (c *Client) GenerateMCQuestions(ctx context.Context, bearerToken string, req GenerateMCQuestionsRequest) ([]GeneratedMCQuestion, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 60 * time.Second}
	}

	url := strings.TrimSuffix(c.BaseURL, "/") + "/content/mc-questions"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+bearerToken)

	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai service unavailable: %w", err)
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode >= http.StatusBadRequest {
		var errBody struct {
			Detail string `json:"detail"`
		}
		if jsonErr := json.Unmarshal(rawBody, &errBody); jsonErr == nil && errBody.Detail != "" {
			return nil, fmt.Errorf("ai service error: %s", errBody.Detail)
		}
		return nil, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}

	var result struct {
		Questions []GeneratedMCQuestion `json:"questions"`
	}
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return nil, fmt.Errorf("ai service: parse response: %w", err)
	}
	return result.Questions, nil
}

// SeedFoundationConceptsRequest is the body for POST /content/seed-concepts.
type SeedFoundationConceptsRequest struct {
	Domain string `json:"domain"`
}

// SeededConcept is one concept returned by the seed endpoint.
type SeededConcept struct {
	CanonicalName  string   `json:"canonical_name"`
	Description    string   `json:"description"`
	Example        string   `json:"example"`
	Analogy        string   `json:"analogy"`
	CommonMistakes string   `json:"common_mistakes"`
	Level          string   `json:"level"`
	Scope          string   `json:"scope"`
	Tags           []string `json:"tags,omitempty"`
}

// SeedFoundationConcepts calls POST /content/seed-concepts on the ai service.
func (c *Client) SeedFoundationConcepts(ctx context.Context, bearerToken string, req SeedFoundationConceptsRequest) ([]SeededConcept, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 60 * time.Second}
	}
	url := strings.TrimSuffix(c.BaseURL, "/") + "/content/seed-concepts"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+bearerToken)
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai service unavailable: %w", err)
	}
	defer resp.Body.Close()
	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= http.StatusBadRequest {
		var errBody struct {
			Detail string `json:"detail"`
		}
		if jsonErr := json.Unmarshal(rawBody, &errBody); jsonErr == nil && errBody.Detail != "" {
			return nil, fmt.Errorf("ai service error: %s", errBody.Detail)
		}
		return nil, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}
	var result struct {
		Concepts []SeededConcept `json:"concepts"`
	}
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return nil, fmt.Errorf("ai service: parse response: %w", err)
	}
	return result.Concepts, nil
}

// DiscoverParentDomainsRequest is the body for POST /content/discover-parent-domains.
type DiscoverParentDomainsRequest struct {
	Domain string `json:"domain"`
}

// DiscoverParentDomains calls POST /content/discover-parent-domains on the ai service.
func (c *Client) DiscoverParentDomains(ctx context.Context, bearerToken string, req DiscoverParentDomainsRequest) ([]string, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 60 * time.Second}
	}
	url := strings.TrimSuffix(c.BaseURL, "/") + "/content/discover-parent-domains"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+bearerToken)
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai service unavailable: %w", err)
	}
	defer resp.Body.Close()
	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= http.StatusBadRequest {
		var errBody struct{ Detail string `json:"detail"` }
		if jsonErr := json.Unmarshal(rawBody, &errBody); jsonErr == nil && errBody.Detail != "" {
			return nil, fmt.Errorf("ai service error: %s", errBody.Detail)
		}
		return nil, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}
	var result struct {
		ParentDomains []string `json:"parent_domains"`
	}
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return nil, fmt.Errorf("ai service: parse response: %w", err)
	}
	return result.ParentDomains, nil
}

// MatchParentConceptsRequest is the body for POST /content/match-parent-concepts.
type MatchParentConceptsRequest struct {
	Domain         string   `json:"domain"`
	ChildConcepts  []string `json:"child_concepts"`
	ParentDomains  []string `json:"parent_domains"`
	ParentConcepts []string `json:"parent_concepts"`
}

// ConceptParentMatch links a child concept to a parent concept.
type ConceptParentMatch struct {
	ChildConcept  string `json:"child_concept"`
	ParentConcept string `json:"parent_concept"`
}

// MatchParentConcepts calls POST /content/match-parent-concepts on the ai service.
func (c *Client) MatchParentConcepts(ctx context.Context, bearerToken string, req MatchParentConceptsRequest) ([]ConceptParentMatch, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 60 * time.Second}
	}
	url := strings.TrimSuffix(c.BaseURL, "/") + "/content/match-parent-concepts"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+bearerToken)
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai service unavailable: %w", err)
	}
	defer resp.Body.Close()
	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= http.StatusBadRequest {
		var errBody struct{ Detail string `json:"detail"` }
		if jsonErr := json.Unmarshal(rawBody, &errBody); jsonErr == nil && errBody.Detail != "" {
			return nil, fmt.Errorf("ai service error: %s", errBody.Detail)
		}
		return nil, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}
	var result struct {
		Matches []ConceptParentMatch `json:"matches"`
	}
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return nil, fmt.Errorf("ai service: parse response: %w", err)
	}
	return result.Matches, nil
}

// GenerateConceptMaterialsRequest is the body for POST /content/concept-materials.
type GenerateConceptMaterialsRequest struct {
	ConceptName    string   `json:"concept_name"`
	Description    string   `json:"description"`
	Example        string   `json:"example"`
	Analogy        string   `json:"analogy"`
	CommonMistakes string   `json:"common_mistakes"`
	Level          string   `json:"level"`
	Domain         string   `json:"domain"`
	Prerequisites  []string `json:"prerequisites"`
	Language       string   `json:"language"`
}

// GeneratedConceptMaterials holds the flashcards and questions returned by the ai service.
type GeneratedConceptMaterials struct {
	Flashcards []GeneratedCard      `json:"flashcards"`
	Questions  []GeneratedMCQuestion `json:"questions"`
}

// GenerateConceptMaterials calls POST /content/concept-materials on the ai service.
func (c *Client) GenerateConceptMaterials(ctx context.Context, bearerToken string, req GenerateConceptMaterialsRequest) (GeneratedConceptMaterials, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return GeneratedConceptMaterials{}, err
	}
	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 90 * time.Second}
	}
	url := strings.TrimSuffix(c.BaseURL, "/") + "/content/concept-materials"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return GeneratedConceptMaterials{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+bearerToken)
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return GeneratedConceptMaterials{}, fmt.Errorf("ai service unavailable: %w", err)
	}
	defer resp.Body.Close()
	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return GeneratedConceptMaterials{}, err
	}
	if resp.StatusCode >= http.StatusBadRequest {
		var errBody struct{ Detail string `json:"detail"` }
		if jsonErr := json.Unmarshal(rawBody, &errBody); jsonErr == nil && errBody.Detail != "" {
			return GeneratedConceptMaterials{}, fmt.Errorf("ai service error: %s", errBody.Detail)
		}
		return GeneratedConceptMaterials{}, fmt.Errorf("ai service returned %d", resp.StatusCode)
	}
	var result GeneratedConceptMaterials
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return GeneratedConceptMaterials{}, fmt.Errorf("ai service: parse response: %w", err)
	}
	return result, nil
}


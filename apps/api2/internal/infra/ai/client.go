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

// GenerateAnkiCardsRequest mirrors the ai service POST /content/anki-cards body.
type GenerateAnkiCardsRequest struct {
	SourceText string `json:"source_text"`
	Language   string `json:"language"`
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

// GenerateAnkiCards calls POST /content/anki-cards on the ai service.
// The bearerToken is forwarded as-is (same JWT secret is shared).
func (c *Client) GenerateAnkiCards(ctx context.Context, bearerToken string, req GenerateAnkiCardsRequest) ([]GeneratedCard, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 60 * time.Second}
	}

	url := strings.TrimSuffix(c.BaseURL, "/") + "/content/anki-cards"
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
		Cards []GeneratedCard `json:"cards"`
	}
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return nil, fmt.Errorf("ai service: parse response: %w", err)
	}
	return result.Cards, nil
}

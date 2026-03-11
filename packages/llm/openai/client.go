// Package openai implements llm.Client using the OpenAI chat completions API.
// It is compatible with any OpenAI-compatible endpoint (e.g. Azure, local proxies).
package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"t2t.dev/llm"
)

var ErrUnexpectedResponse = errors.New("unexpected llm response")

// Client calls the OpenAI (or compatible) chat completions endpoint.
type Client struct {
	APIKey     string
	Model      string // default model; overridden per-request if Request.Model is set
	BaseURL    string // defaults to https://api.openai.com/v1
	HTTPClient *http.Client
	// Logger receives one structured log entry per completion with the prompt and response.
	// If nil, no logging is performed.
	Logger *slog.Logger
}

// Complete sends a chat completion request and returns the model's text response.
// If Request.JSONMode is true, the response format is set to json_object and
// any markdown code fences are stripped before returning.
func (c *Client) Complete(ctx context.Context, req llm.Request) (string, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return "", errors.New("llm/openai: missing API key")
	}

	model := req.Model
	if model == "" {
		model = fallback(c.Model, "gpt-4o-mini")
	}

	payload := chatRequest{
		Model:       model,
		Temperature: req.Temperature,
		Messages: []chatMessage{
			{Role: "system", Content: req.SystemPrompt},
			{Role: "user", Content: req.UserPrompt},
		},
	}
	if req.JSONMode {
		payload.ResponseFormat = map[string]string{"type": "json_object"}
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint(c.BaseURL), bytes.NewReader(encoded))
	if err != nil {
		return "", err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+c.APIKey)

	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 45 * time.Second}
	}

	resp, err := httpClient.Do(httpReq)
	if err != nil {
		if c.Logger != nil {
			c.Logger.ErrorContext(ctx, "llm request failed",
				"model", model,
				"system_prompt", req.SystemPrompt,
				"user_prompt", req.UserPrompt,
				"error", err,
			)
		}
		return "", err
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if resp.StatusCode >= http.StatusBadRequest {
		provErr := providerError(rawBody)
		if c.Logger != nil {
			c.Logger.ErrorContext(ctx, "llm provider error",
				"model", model,
				"status", resp.StatusCode,
				"system_prompt", req.SystemPrompt,
				"user_prompt", req.UserPrompt,
				"provider_error", provErr,
			)
		}
		return "", fmt.Errorf("llm/openai: provider returned %d: %s", resp.StatusCode, provErr)
	}

	var completion chatResponse
	if err := json.Unmarshal(rawBody, &completion); err != nil {
		return "", fmt.Errorf("llm/openai: parse response: %w", err)
	}
	if len(completion.Choices) == 0 {
		return "", ErrUnexpectedResponse
	}

	content := strings.TrimSpace(completion.Choices[0].Message.Content)
	if content == "" {
		return "", ErrUnexpectedResponse
	}
	if req.JSONMode {
		content = stripFence(content)
	}

	if c.Logger != nil {
		c.Logger.InfoContext(ctx, "llm completion",
			"model", model,
			"system_prompt", req.SystemPrompt,
			"user_prompt", req.UserPrompt,
			"response", content,
		)
	}

	return content, nil
}

// --- private types & helpers ---

type chatRequest struct {
	Model          string            `json:"model"`
	Temperature    float64           `json:"temperature"`
	Messages       []chatMessage     `json:"messages"`
	ResponseFormat map[string]string `json:"response_format,omitempty"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

type providerErrBody struct {
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

func endpoint(baseURL string) string {
	base := strings.TrimSuffix(strings.TrimSpace(baseURL), "/")
	if base == "" {
		base = "https://api.openai.com/v1"
	}
	return base + "/chat/completions"
}

func providerError(body []byte) string {
	var parsed providerErrBody
	if err := json.Unmarshal(body, &parsed); err == nil && strings.TrimSpace(parsed.Error.Message) != "" {
		return strings.TrimSpace(parsed.Error.Message)
	}
	if msg := strings.TrimSpace(string(body)); msg != "" {
		return msg
	}
	return "unknown provider error"
}

func stripFence(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "```json")
	s = strings.TrimPrefix(s, "```")
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}

func fallback(value, def string) string {
	if v := strings.TrimSpace(value); v != "" {
		return v
	}
	return def
}

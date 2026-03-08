package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	domaincontent "ai/internal/domain/content"
	"ai/internal/prompts"
	"ai/internal/sharedmodels"
)

var ErrUnexpectedResponse = errors.New("unexpected ai response")

type Client struct {
	APIKey     string
	Model      string
	BaseURL    string
	HTTPClient *http.Client
	Prompts    *prompts.Registry
}

type chatCompletionsRequest struct {
	Model          string            `json:"model"`
	Temperature    float64           `json:"temperature"`
	Messages       []chatMessage     `json:"messages"`
	ResponseFormat map[string]string `json:"response_format,omitempty"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatCompletionsResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

type providerErrorResponse struct {
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

// ListLessonTitles calls the LLM to generate a list of lesson title candidates.
func (c Client) ListLessonTitles(ctx context.Context, input domaincontent.ListTitlesInput) ([]string, error) {
	userPrompt, err := c.Prompts.RenderListTitles(prompts.ListTitlesData{
		SkillTitle: input.SkillTitle,
		Count:      input.Count,
		Audience:   input.Audience,
		Difficulty: input.Difficulty,
		Language:   input.Language,
	})
	if err != nil {
		return nil, err
	}

	raw, err := c.complete(ctx, userPrompt)
	if err != nil {
		return nil, err
	}

	var result struct {
		Titles []string `json:"titles"`
	}
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return nil, fmt.Errorf("parse lesson titles response: %w", err)
	}
	if len(result.Titles) == 0 {
		return nil, ErrUnexpectedResponse
	}
	return result.Titles, nil
}

// GenerateLesson calls the LLM to generate full content for a single lesson.
func (c Client) GenerateLesson(ctx context.Context, input domaincontent.GenerateLessonInput) (sharedmodels.Lesson, error) {
	userPrompt, err := c.Prompts.RenderGenerateLesson(prompts.GenerateLessonData{
		LessonTitle: input.LessonTitle,
		SkillTitle:  input.SkillTitle,
		Audience:    input.Audience,
		Difficulty:  input.Difficulty,
		Language:    input.Language,
	})
	if err != nil {
		return sharedmodels.Lesson{}, err
	}

	raw, err := c.complete(ctx, userPrompt)
	if err != nil {
		return sharedmodels.Lesson{}, err
	}

	var lesson sharedmodels.Lesson
	if err := json.Unmarshal([]byte(raw), &lesson); err != nil {
		return sharedmodels.Lesson{}, fmt.Errorf("parse lesson response: %w", err)
	}
	if strings.TrimSpace(lesson.Title) == "" {
		return sharedmodels.Lesson{}, ErrUnexpectedResponse
	}
	return lesson, nil
}

// complete sends a chat completion request and returns the raw JSON response content.
func (c Client) complete(ctx context.Context, userPrompt string) (string, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return "", errors.New("missing ai api key")
	}

	payload := chatCompletionsRequest{
		Model:       fallback(c.Model, "gpt-4o-mini"),
		Temperature: 0.7,
		Messages: []chatMessage{
			{Role: "system", Content: c.Prompts.SystemPrompt()},
			{Role: "user", Content: userPrompt},
		},
		ResponseFormat: map[string]string{"type": "json_object"},
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint(c.BaseURL), bytes.NewReader(encoded))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.APIKey)

	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 45 * time.Second}
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if resp.StatusCode >= http.StatusBadRequest {
		return "", fmt.Errorf("ai provider returned %d: %s", resp.StatusCode, providerError(rawBody))
	}

	var completion chatCompletionsResponse
	if err := json.Unmarshal(rawBody, &completion); err != nil {
		return "", fmt.Errorf("parse chat completion: %w", err)
	}
	if len(completion.Choices) == 0 {
		return "", ErrUnexpectedResponse
	}

	content := strings.TrimSpace(completion.Choices[0].Message.Content)
	if content == "" {
		return "", ErrUnexpectedResponse
	}
	return stripFence(content), nil
}

func endpoint(baseURL string) string {
	normalized := strings.TrimSuffix(strings.TrimSpace(baseURL), "/")
	if normalized == "" {
		normalized = "https://api.openai.com/v1"
	}
	return normalized + "/chat/completions"
}

func providerError(rawBody []byte) string {
	var parsed providerErrorResponse
	if err := json.Unmarshal(rawBody, &parsed); err == nil && strings.TrimSpace(parsed.Error.Message) != "" {
		return strings.TrimSpace(parsed.Error.Message)
	}
	msg := strings.TrimSpace(string(rawBody))
	if msg == "" {
		return "unknown provider error"
	}
	return msg
}

func fallback(value, defaultValue string) string {
	if trimmed := strings.TrimSpace(value); trimmed != "" {
		return trimmed
	}
	return defaultValue
}

func stripFence(value string) string {
	trimmed := strings.TrimSpace(value)
	trimmed = strings.TrimPrefix(trimmed, "```json")
	trimmed = strings.TrimPrefix(trimmed, "```")
	trimmed = strings.TrimSuffix(trimmed, "```")
	return strings.TrimSpace(trimmed)
}

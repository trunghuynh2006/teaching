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
	"ai/internal/sharedmodels"
)

var ErrUnexpectedResponse = errors.New("unexpected ai response")

type Client struct {
	APIKey     string
	Model      string
	BaseURL    string
	HTTPClient *http.Client
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

type generatedPayload struct {
	Lesson sharedmodels.Lesson `json:"lesson"`
	Skill  sharedmodels.Skill  `json:"skill"`
}

type providerErrorResponse struct {
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

func (c Client) GenerateLessonSkill(ctx context.Context, input domaincontent.GenerateInput) (domaincontent.GenerateOutput, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return domaincontent.GenerateOutput{}, errors.New("missing ai api key")
	}

	payload := chatCompletionsRequest{
		Model:       fallback(c.Model, "gpt-4o-mini"),
		Temperature: 0.7,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: buildUserPrompt(input)},
		},
		ResponseFormat: map[string]string{"type": "json_object"},
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		return domaincontent.GenerateOutput{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint(c.BaseURL), bytes.NewReader(encoded))
	if err != nil {
		return domaincontent.GenerateOutput{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.APIKey)

	client := c.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 45 * time.Second}
	}

	resp, err := client.Do(req)
	if err != nil {
		return domaincontent.GenerateOutput{}, err
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return domaincontent.GenerateOutput{}, err
	}

	if resp.StatusCode >= http.StatusBadRequest {
		return domaincontent.GenerateOutput{}, fmt.Errorf("ai provider returned %d: %s", resp.StatusCode, providerError(rawBody))
	}

	var completion chatCompletionsResponse
	if err := json.Unmarshal(rawBody, &completion); err != nil {
		return domaincontent.GenerateOutput{}, fmt.Errorf("parse chat completion: %w", err)
	}
	if len(completion.Choices) == 0 {
		return domaincontent.GenerateOutput{}, ErrUnexpectedResponse
	}

	content := strings.TrimSpace(completion.Choices[0].Message.Content)
	if content == "" {
		return domaincontent.GenerateOutput{}, ErrUnexpectedResponse
	}

	var generated generatedPayload
	if err := json.Unmarshal([]byte(stripFence(content)), &generated); err != nil {
		return domaincontent.GenerateOutput{}, fmt.Errorf("parse generated payload: %w", err)
	}

	if strings.TrimSpace(generated.Lesson.Title) == "" || strings.TrimSpace(generated.Skill.Title) == "" {
		return domaincontent.GenerateOutput{}, ErrUnexpectedResponse
	}

	return domaincontent.GenerateOutput{Lesson: generated.Lesson, Skill: generated.Skill}, nil
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
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return defaultValue
	}
	return trimmed
}

func buildUserPrompt(input domaincontent.GenerateInput) string {
	return fmt.Sprintf(`Generate a lesson and skill for this topic.

Topic: %s
Audience: %s
Difficulty: %s
Language: %s

Respond with valid JSON only, no markdown.
JSON shape:
{
  "lesson": {
    "id": "string",
    "title": "string",
    "description": "string",
    "duration_minutes": 1,
    "is_published": false,
    "tags": ["string"]
  },
  "skill": {
    "id": "string",
    "title": "string",
    "description": "string",
    "difficulty": "beginner",
    "is_published": false,
    "tags": ["string"]
  }
}

Keep titles concise and description under 160 characters.`, input.Topic, input.Audience, input.Difficulty, input.Language)
}

func stripFence(value string) string {
	trimmed := strings.TrimSpace(value)
	trimmed = strings.TrimPrefix(trimmed, "```json")
	trimmed = strings.TrimPrefix(trimmed, "```")
	trimmed = strings.TrimSuffix(trimmed, "```")
	return strings.TrimSpace(trimmed)
}

const systemPrompt = `You are a curriculum assistant for teachers.
Generate practical learning content and follow the requested JSON shape exactly.`

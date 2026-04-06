package openai

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	domaincontent "ai/internal/domain/content"
	"ai/internal/prompts"
	"ai/internal/sharedmodels"
	"t2t.dev/llm"
	llmopenai "t2t.dev/llm/openai"
)

var ErrUnexpectedResponse = llmopenai.ErrUnexpectedResponse

// Client implements domaincontent.Generator using the shared llm package.
type Client struct {
	LLM     llm.Client
	Prompts *prompts.Registry
}

// NewOpenAIClient constructs a Client backed by the OpenAI-compatible provider.
// Pass a non-nil logger to write every prompt/response to a log file.
func NewOpenAIClient(apiKey, model, baseURL string, prompts *prompts.Registry, logger *slog.Logger) Client {
	return Client{
		LLM: &llmopenai.Client{
			APIKey:  apiKey,
			Model:   model,
			BaseURL: baseURL,
			Logger:  logger,
		},
		Prompts: prompts,
	}
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

// GenerateAnkiCards calls the LLM to generate Anki card suggestions from source text.
func (c Client) GenerateAnkiCards(ctx context.Context, input domaincontent.GenerateAnkiCardsInput) ([]domaincontent.GeneratedAnkiCard, error) {
	userPrompt, err := c.Prompts.RenderGenerateAnkiCards(prompts.GenerateAnkiCardsData{
		SourceText: input.SourceText,
		Language:   input.Language,
	})
	if err != nil {
		return nil, err
	}

	raw, err := c.complete(ctx, userPrompt)
	if err != nil {
		return nil, err
	}

	// The LLM sometimes echoes the full JSON schema alongside the actual data.
	// "properties" contains schema metadata (objects), not card data — ignore it.
	var result struct {
		Cards      []domaincontent.GeneratedAnkiCard `json:"cards"`
		Properties json.RawMessage                   `json:"properties"`
	}
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return nil, fmt.Errorf("parse anki cards response: %w", err)
	}
	if len(result.Cards) == 0 {
		return nil, ErrUnexpectedResponse
	}
	return result.Cards, nil
}

// ExtractConcepts calls the LLM to extract concepts from source text.
func (c Client) ExtractConcepts(ctx context.Context, input domaincontent.ExtractConceptsInput) ([]domaincontent.ExtractedConcept, error) {
	userPrompt, err := c.Prompts.RenderExtractConcepts(prompts.ExtractConceptsData{
		SourceText: input.SourceText,
		Language:   input.Language,
		Domain:     input.Domain,
	})
	if err != nil {
		return nil, err
	}

	raw, err := c.complete(ctx, userPrompt)
	if err != nil {
		return nil, err
	}

	// The LLM sometimes echoes the schema structure back, placing concepts
	// under "properties.concepts" instead of the top-level "concepts" key.
	// Try both locations before giving up.
	var result struct {
		Concepts   []domaincontent.ExtractedConcept `json:"concepts"`
		Properties struct {
			Concepts []domaincontent.ExtractedConcept `json:"concepts"`
		} `json:"properties"`
	}
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return nil, fmt.Errorf("parse concepts response: %w", err)
	}
	concepts := result.Concepts
	if len(concepts) == 0 {
		concepts = result.Properties.Concepts
	}
	if len(concepts) == 0 {
		return nil, ErrUnexpectedResponse
	}
	return concepts, nil
}

// GenerateMCQuestions calls the LLM to generate multiple-choice questions from source text.
func (c Client) GenerateMCQuestions(ctx context.Context, input domaincontent.GenerateMCQuestionsInput) ([]domaincontent.GeneratedMCQuestion, error) {
	userPrompt, err := c.Prompts.RenderGenerateMCQuestions(prompts.GenerateMCQuestionsData{
		SourceText: input.SourceText,
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
		Questions  []domaincontent.GeneratedMCQuestion `json:"questions"`
		Properties json.RawMessage                     `json:"properties"`
	}
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return nil, fmt.Errorf("parse mc questions response: %w", err)
	}
	if len(result.Questions) == 0 {
		return nil, ErrUnexpectedResponse
	}
	return result.Questions, nil
}

// SeedFoundationConcepts calls the LLM to generate foundation concepts for a domain.
func (c Client) SeedFoundationConcepts(ctx context.Context, input domaincontent.SeedFoundationConceptsInput) ([]domaincontent.SeededConcept, error) {
	userPrompt, err := c.Prompts.RenderSeedFoundationConcepts(prompts.SeedFoundationConceptsData{
		Domain: input.Domain,
	})
	if err != nil {
		return nil, err
	}

	raw, err := c.complete(ctx, userPrompt)
	if err != nil {
		return nil, err
	}

	var result struct {
		Concepts []domaincontent.SeededConcept `json:"concepts"`
	}
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return nil, fmt.Errorf("parse seed concepts response: %w", err)
	}
	if len(result.Concepts) == 0 {
		return nil, ErrUnexpectedResponse
	}
	return result.Concepts, nil
}

// DiscoverParentDomains calls the LLM to find parent domains for a given domain.
func (c Client) DiscoverParentDomains(ctx context.Context, input domaincontent.DiscoverParentDomainsInput) ([]string, error) {
	userPrompt, err := c.Prompts.RenderDiscoverParentDomains(prompts.DiscoverParentDomainsData{
		Domain: input.Domain,
	})
	if err != nil {
		return nil, err
	}
	raw, err := c.complete(ctx, userPrompt)
	if err != nil {
		return nil, err
	}
	var result struct {
		ParentDomains []string `json:"parent_domains"`
	}
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return nil, fmt.Errorf("parse discover-parent-domains response: %w", err)
	}
	return result.ParentDomains, nil
}

// MatchParentConcepts calls the LLM to link child concepts to parent domain concepts.
func (c Client) MatchParentConcepts(ctx context.Context, input domaincontent.MatchParentConceptsInput) ([]domaincontent.ConceptParentMatch, error) {
	userPrompt, err := c.Prompts.RenderMatchParentConcepts(prompts.MatchParentConceptsData{
		Domain:         input.Domain,
		ChildConcepts:  input.ChildConcepts,
		ParentDomains:  input.ParentDomains,
		ParentConcepts: input.ParentConcepts,
	})
	if err != nil {
		return nil, err
	}
	raw, err := c.complete(ctx, userPrompt)
	if err != nil {
		return nil, err
	}
	var result struct {
		Matches []domaincontent.ConceptParentMatch `json:"matches"`
	}
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return nil, fmt.Errorf("parse match-parent-concepts response: %w", err)
	}
	return result.Matches, nil
}

func (c Client) complete(ctx context.Context, userPrompt string) (string, error) {
	return c.LLM.Complete(ctx, llm.Request{
		SystemPrompt: c.Prompts.SystemPrompt(),
		UserPrompt:   userPrompt,
		Temperature:  0.7,
		JSONMode:     true,
	})
}

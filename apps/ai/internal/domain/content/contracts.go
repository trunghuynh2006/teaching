package content

import (
	"context"
	"encoding/json"

	"ai/internal/sharedmodels"
)

// ListTitlesInput describes a request to generate lesson title candidates for a skill.
type ListTitlesInput struct {
	SkillTitle string
	Count      int
	Audience   string
	Difficulty string
	Language   string
}

// GenerateLessonInput describes a request to generate full content for a single lesson.
type GenerateLessonInput struct {
	LessonTitle string
	SkillTitle  string
	Audience    string
	Difficulty  string
	Language    string
}

// GenerateAnkiCardsInput describes a request to generate Anki cards from source text.
type GenerateAnkiCardsInput struct {
	SourceText string
	Language   string
}

// GeneratedAnkiCard is a suggested card returned by the AI before it is persisted.
type GeneratedAnkiCard struct {
	FrontText  string   `json:"front_text"`
	BackText   string   `json:"back_text"`
	BloomLevel string   `json:"bloom_level"`
	Tags       []string `json:"tags,omitempty"`
}

// ExtractConceptsInput describes a request to extract concepts from source text.
type ExtractConceptsInput struct {
	SourceText string
	Language   string
	Domain     string // optional hint to guide the LLM (e.g. folder domain)
}

// ExtractedConcept is a concept identified by the AI from source text.
type ExtractedConcept struct {
	CanonicalName string   `json:"canonical_name"`
	Description   string   `json:"description"`
	Domain        string   `json:"domain,omitempty"`
	Tags          []string `json:"tags,omitempty"`
	Aliases       []string `json:"aliases,omitempty"`
	Prerequisites []string `json:"prerequisites,omitempty"`
}

// GenerateMCQuestionsInput describes a request to generate multiple-choice questions from source text.
type GenerateMCQuestionsInput struct {
	SourceText string
	Language   string
}

// GeneratedMCAnswer is one answer choice in a generated multiple-choice question.
type GeneratedMCAnswer struct {
	Text      string `json:"text"`
	IsCorrect bool   `json:"is_correct"`
}

// GeneratedMCQuestion is one multiple-choice question returned by the AI.
type GeneratedMCQuestion struct {
	Body    string              `json:"body"`
	Answers []GeneratedMCAnswer `json:"answers"`
}

// SeedFoundationConceptsInput describes a request to generate foundation concepts for a domain.
type SeedFoundationConceptsInput struct {
	Domain string
}

// SeededConcept is one foundation concept returned by the AI.
type SeededConcept struct {
	CanonicalName string   `json:"canonical_name"`
	Description   string   `json:"description"`
	Level         string   `json:"level"`
	Scope         string   `json:"scope"`
	Tags          []string `json:"tags,omitempty"`
}

// Generator produces AI-generated curriculum content.
type Generator interface {
	// ListLessonTitles returns Count candidate lesson titles for the given skill.
	ListLessonTitles(ctx context.Context, input ListTitlesInput) ([]string, error)
	// GenerateLesson returns fully populated lesson content for a given title.
	GenerateLesson(ctx context.Context, input GenerateLessonInput) (sharedmodels.Lesson, error)
	// GenerateAnkiCards returns suggested Anki cards derived from the given source text.
	GenerateAnkiCards(ctx context.Context, input GenerateAnkiCardsInput) ([]GeneratedAnkiCard, error)
	// ExtractConcepts returns concepts identified in the given source text.
	ExtractConcepts(ctx context.Context, input ExtractConceptsInput) ([]ExtractedConcept, error)
	// GenerateMCQuestions returns multiple-choice questions derived from the given source text.
	GenerateMCQuestions(ctx context.Context, input GenerateMCQuestionsInput) ([]GeneratedMCQuestion, error)
	// SeedFoundationConcepts returns a list of foundational concepts for the given domain.
	SeedFoundationConcepts(ctx context.Context, input SeedFoundationConceptsInput) ([]SeededConcept, error)
}

// Cache stores and retrieves serialised generation results keyed by a prompt hash.
// Values are raw JSON so the cache layer stays agnostic of the response shape.
type Cache interface {
	Get(ctx context.Context, key string) (json.RawMessage, bool)
	Set(ctx context.Context, key string, value json.RawMessage)
}

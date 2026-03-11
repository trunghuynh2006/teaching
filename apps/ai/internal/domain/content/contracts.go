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

// Generator produces AI-generated curriculum content.
type Generator interface {
	// ListLessonTitles returns Count candidate lesson titles for the given skill.
	ListLessonTitles(ctx context.Context, input ListTitlesInput) ([]string, error)
	// GenerateLesson returns fully populated lesson content for a given title.
	GenerateLesson(ctx context.Context, input GenerateLessonInput) (sharedmodels.Lesson, error)
	// GenerateAnkiCards returns suggested Anki cards derived from the given source text.
	GenerateAnkiCards(ctx context.Context, input GenerateAnkiCardsInput) ([]GeneratedAnkiCard, error)
}

// Cache stores and retrieves serialised generation results keyed by a prompt hash.
// Values are raw JSON so the cache layer stays agnostic of the response shape.
type Cache interface {
	Get(ctx context.Context, key string) (json.RawMessage, bool)
	Set(ctx context.Context, key string, value json.RawMessage)
}

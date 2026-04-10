package content

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode"

	domaincontent "ai/internal/domain/content"
	"ai/internal/sharedmodels"
)

var (
	ErrInvalidSkillTitle    = errors.New("skill title is required")
	ErrInvalidLessonTitle   = errors.New("lesson title is required")
	ErrInvalidSourceText    = errors.New("source text is required")
	ErrGeneratorUnavailable = errors.New("generator is not configured")
)

type Service struct {
	Generator domaincontent.Generator
	Cache     domaincontent.Cache
}

// ListTitlesInput is the application-layer input for listing lesson title candidates.
type ListTitlesInput struct {
	SkillTitle string
	Count      int
	Audience   string
	Difficulty string
	Language   string
}

// GenerateLessonInput is the application-layer input for generating a full lesson.
type GenerateLessonInput struct {
	LessonTitle string
	SkillTitle  string
	Audience    string
	Difficulty  string
	Language    string
}

// ExtractConceptsInput is the application-layer input for extracting concepts from source text.
type ExtractConceptsInput struct {
	SourceText string
	Language   string
	Domain     string
}

// ListLessonTitles generates a list of candidate lesson titles for a skill.
func (s Service) ListLessonTitles(ctx context.Context, input ListTitlesInput) ([]string, error) {
	if strings.TrimSpace(input.SkillTitle) == "" {
		return nil, ErrInvalidSkillTitle
	}
	if s.Generator == nil {
		return nil, ErrGeneratorUnavailable
	}

	count := input.Count
	if count <= 0 {
		count = 5
	}

	normalized := domaincontent.ListTitlesInput{
		SkillTitle: strings.TrimSpace(input.SkillTitle),
		Count:      count,
		Audience:   fallback(input.Audience, "middle school students"),
		Difficulty: normalizeDifficulty(input.Difficulty),
		Language:   fallback(input.Language, "English"),
	}

	cacheKey := hashKey("list-titles", normalized)
	if s.Cache != nil {
		if raw, ok := s.Cache.Get(ctx, cacheKey); ok {
			var titles []string
			if err := json.Unmarshal(raw, &titles); err == nil {
				return titles, nil
			}
		}
	}

	titles, err := s.Generator.ListLessonTitles(ctx, normalized)
	if err != nil {
		return nil, err
	}

	if s.Cache != nil {
		if raw, err := json.Marshal(titles); err == nil {
			s.Cache.Set(ctx, cacheKey, raw)
		}
	}
	return titles, nil
}

// GenerateLesson generates full lesson content for a given title within a skill.
func (s Service) GenerateLesson(ctx context.Context, input GenerateLessonInput) (sharedmodels.Lesson, error) {
	if strings.TrimSpace(input.LessonTitle) == "" {
		return sharedmodels.Lesson{}, ErrInvalidLessonTitle
	}
	if s.Generator == nil {
		return sharedmodels.Lesson{}, ErrGeneratorUnavailable
	}

	normalized := domaincontent.GenerateLessonInput{
		LessonTitle: strings.TrimSpace(input.LessonTitle),
		SkillTitle:  strings.TrimSpace(input.SkillTitle),
		Audience:    fallback(input.Audience, "middle school students"),
		Difficulty:  normalizeDifficulty(input.Difficulty),
		Language:    fallback(input.Language, "English"),
	}

	cacheKey := hashKey("generate-lesson", normalized)
	if s.Cache != nil {
		if raw, ok := s.Cache.Get(ctx, cacheKey); ok {
			var lesson sharedmodels.Lesson
			if err := json.Unmarshal(raw, &lesson); err == nil {
				return lesson, nil
			}
		}
	}

	lesson, err := s.Generator.GenerateLesson(ctx, normalized)
	if err != nil {
		return sharedmodels.Lesson{}, err
	}

	if strings.TrimSpace(lesson.Id) == "" {
		lesson.Id = defaultID(normalized.LessonTitle)
	}
	if strings.TrimSpace(lesson.Title) == "" {
		return sharedmodels.Lesson{}, fmt.Errorf("generated lesson is missing a title")
	}

	if s.Cache != nil {
		if raw, err := json.Marshal(lesson); err == nil {
			s.Cache.Set(ctx, cacheKey, raw)
		}
	}
	return lesson, nil
}

// ExtractConcepts extracts concepts from a given source text.
func (s Service) ExtractConcepts(ctx context.Context, input ExtractConceptsInput) ([]domaincontent.ExtractedConcept, error) {
	if strings.TrimSpace(input.SourceText) == "" {
		return nil, ErrInvalidSourceText
	}
	if s.Generator == nil {
		return nil, ErrGeneratorUnavailable
	}

	normalized := domaincontent.ExtractConceptsInput{
		SourceText: strings.TrimSpace(input.SourceText),
		Language:   fallback(input.Language, "English"),
		Domain:     strings.TrimSpace(input.Domain),
	}

	cacheKey := hashKey("extract-concepts", normalized)
	if s.Cache != nil {
		if raw, ok := s.Cache.Get(ctx, cacheKey); ok {
			var concepts []domaincontent.ExtractedConcept
			if err := json.Unmarshal(raw, &concepts); err == nil {
				return concepts, nil
			}
		}
	}

	concepts, err := s.Generator.ExtractConcepts(ctx, normalized)
	if err != nil {
		return nil, err
	}

	if s.Cache != nil {
		if raw, err := json.Marshal(concepts); err == nil {
			s.Cache.Set(ctx, cacheKey, raw)
		}
	}
	return concepts, nil
}

// GenerateMCQuestionsInput is the application-layer input for generating multiple-choice questions.
type GenerateMCQuestionsInput struct {
	SourceText string
	Language   string
}

// GenerateMCQuestions generates multiple-choice questions from a given source text.
func (s Service) GenerateMCQuestions(ctx context.Context, input GenerateMCQuestionsInput) ([]domaincontent.GeneratedMCQuestion, error) {
	if strings.TrimSpace(input.SourceText) == "" {
		return nil, ErrInvalidSourceText
	}
	if s.Generator == nil {
		return nil, ErrGeneratorUnavailable
	}

	normalized := domaincontent.GenerateMCQuestionsInput{
		SourceText: strings.TrimSpace(input.SourceText),
		Language:   fallback(input.Language, "English"),
	}

	cacheKey := hashKey("generate-mc-questions", normalized)
	if s.Cache != nil {
		if raw, ok := s.Cache.Get(ctx, cacheKey); ok {
			var questions []domaincontent.GeneratedMCQuestion
			if err := json.Unmarshal(raw, &questions); err == nil {
				return questions, nil
			}
		}
	}

	questions, err := s.Generator.GenerateMCQuestions(ctx, normalized)
	if err != nil {
		return nil, err
	}

	if s.Cache != nil {
		if raw, err := json.Marshal(questions); err == nil {
			s.Cache.Set(ctx, cacheKey, raw)
		}
	}
	return questions, nil
}

// SeedFoundationConceptsInput is the application-layer input for seeding foundation concepts.
type SeedFoundationConceptsInput struct {
	Domain string
}

// SeedFoundationConcepts generates a curated list of foundational concepts for a domain.
func (s Service) SeedFoundationConcepts(ctx context.Context, input SeedFoundationConceptsInput) ([]domaincontent.SeededConcept, error) {
	if s.Generator == nil {
		return nil, ErrGeneratorUnavailable
	}
	normalized := domaincontent.SeedFoundationConceptsInput{
		Domain: strings.TrimSpace(input.Domain),
	}
	cacheKey := hashKey("seed-foundation-concepts", normalized)
	if s.Cache != nil {
		if raw, ok := s.Cache.Get(ctx, cacheKey); ok {
			var concepts []domaincontent.SeededConcept
			if err := json.Unmarshal(raw, &concepts); err == nil {
				return concepts, nil
			}
		}
	}
	concepts, err := s.Generator.SeedFoundationConcepts(ctx, normalized)
	if err != nil {
		return nil, err
	}
	if s.Cache != nil {
		if raw, err := json.Marshal(concepts); err == nil {
			s.Cache.Set(ctx, cacheKey, raw)
		}
	}
	return concepts, nil
}

// DiscoverParentDomainsInput is the application-layer input.
type DiscoverParentDomainsInput struct {
	Domain string
}

// DiscoverParentDomains returns parent domain names for a given domain.
func (s Service) DiscoverParentDomains(ctx context.Context, input DiscoverParentDomainsInput) ([]string, error) {
	if s.Generator == nil {
		return nil, ErrGeneratorUnavailable
	}
	normalized := domaincontent.DiscoverParentDomainsInput{Domain: strings.TrimSpace(input.Domain)}
	cacheKey := hashKey("discover-parent-domains", normalized)
	if s.Cache != nil {
		if raw, ok := s.Cache.Get(ctx, cacheKey); ok {
			var domains []string
			if err := json.Unmarshal(raw, &domains); err == nil {
				return domains, nil
			}
		}
	}
	domains, err := s.Generator.DiscoverParentDomains(ctx, normalized)
	if err != nil {
		return nil, err
	}
	if s.Cache != nil {
		if raw, err := json.Marshal(domains); err == nil {
			s.Cache.Set(ctx, cacheKey, raw)
		}
	}
	return domains, nil
}

// MatchParentConceptsInput is the application-layer input.
type MatchParentConceptsInput struct {
	Domain         string
	ChildConcepts  []string
	ParentDomains  []string
	ParentConcepts []string
}

// MatchParentConcepts returns concept-to-parent-concept pairs.
func (s Service) MatchParentConcepts(ctx context.Context, input MatchParentConceptsInput) ([]domaincontent.ConceptParentMatch, error) {
	if s.Generator == nil {
		return nil, ErrGeneratorUnavailable
	}
	normalized := domaincontent.MatchParentConceptsInput{
		Domain:         strings.TrimSpace(input.Domain),
		ChildConcepts:  input.ChildConcepts,
		ParentDomains:  input.ParentDomains,
		ParentConcepts: input.ParentConcepts,
	}
	// No cache for this one — inputs are large and variable
	return s.Generator.MatchParentConcepts(ctx, normalized)
}

// GenerateConceptMaterialsInput is the application-layer input.
type GenerateConceptMaterialsInput struct {
	ConceptName    string
	Description    string
	Example        string
	Analogy        string
	CommonMistakes string
	Level          string
	Domain         string
	Prerequisites  []string
	Language       string
}

// GenerateConceptMaterials generates flashcards and MC questions for a specific concept.
func (s Service) GenerateConceptMaterials(ctx context.Context, input GenerateConceptMaterialsInput) (domaincontent.GeneratedConceptMaterials, error) {
	if strings.TrimSpace(input.ConceptName) == "" {
		return domaincontent.GeneratedConceptMaterials{}, errors.New("concept name is required")
	}
	if s.Generator == nil {
		return domaincontent.GeneratedConceptMaterials{}, ErrGeneratorUnavailable
	}

	normalized := domaincontent.ConceptMaterialsInput{
		ConceptName:    strings.TrimSpace(input.ConceptName),
		Description:    strings.TrimSpace(input.Description),
		Example:        strings.TrimSpace(input.Example),
		Analogy:        strings.TrimSpace(input.Analogy),
		CommonMistakes: strings.TrimSpace(input.CommonMistakes),
		Level:          strings.TrimSpace(input.Level),
		Domain:         strings.TrimSpace(input.Domain),
		Prerequisites:  input.Prerequisites,
		Language:       fallback(input.Language, "English"),
	}

	cacheKey := hashKey("generate-concept-materials", normalized)
	if s.Cache != nil {
		if raw, ok := s.Cache.Get(ctx, cacheKey); ok {
			var result domaincontent.GeneratedConceptMaterials
			if err := json.Unmarshal(raw, &result); err == nil {
				return result, nil
			}
		}
	}

	result, err := s.Generator.GenerateConceptMaterials(ctx, normalized)
	if err != nil {
		return domaincontent.GeneratedConceptMaterials{}, err
	}

	if s.Cache != nil {
		if raw, err := json.Marshal(result); err == nil {
			s.Cache.Set(ctx, cacheKey, raw)
		}
	}
	return result, nil
}

func hashKey(prefix string, v any) string {
	payload, err := json.Marshal(v)
	if err != nil {
		return prefix + ":fallback:" + fmt.Sprint(v)
	}
	sum := sha256.Sum256(append([]byte(prefix+":"), payload...))
	return hex.EncodeToString(sum[:])
}

func fallback(value, defaultValue string) string {
	if trimmed := strings.TrimSpace(value); trimmed != "" {
		return trimmed
	}
	return defaultValue
}

func normalizeDifficulty(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "beginner", "intermediate", "advanced":
		return strings.ToLower(strings.TrimSpace(value))
	default:
		return "beginner"
	}
}

func defaultID(title string) string {
	slug := slugify(title)
	if slug == "" {
		slug = "lesson"
	}
	return fmt.Sprintf("%s-%d", slug, time.Now().Unix())
}

func slugify(value string) string {
	var b strings.Builder
	lastHyphen := false
	for _, r := range strings.ToLower(strings.TrimSpace(value)) {
		switch {
		case unicode.IsLetter(r), unicode.IsDigit(r):
			b.WriteRune(r)
			lastHyphen = false
		case !lastHyphen:
			b.WriteRune('-')
			lastHyphen = true
		}
	}
	return strings.Trim(b.String(), "-")
}

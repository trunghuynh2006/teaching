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

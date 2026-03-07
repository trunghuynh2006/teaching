package content

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode"

	domaincontent "ai/internal/domain/content"
)

var (
	ErrInvalidTopic         = errors.New("topic is required")
	ErrGeneratorUnavailable = errors.New("generator is not configured")
)

type Service struct {
	Generator domaincontent.Generator
}

type GenerateInput struct {
	Topic      string
	Audience   string
	Difficulty string
	Language   string
}

func (s Service) GenerateLessonSkill(ctx context.Context, input GenerateInput) (domaincontent.GenerateOutput, error) {
	topic := strings.TrimSpace(input.Topic)
	if topic == "" {
		return domaincontent.GenerateOutput{}, ErrInvalidTopic
	}
	if s.Generator == nil {
		return domaincontent.GenerateOutput{}, ErrGeneratorUnavailable
	}

	output, err := s.Generator.GenerateLessonSkill(ctx, domaincontent.GenerateInput{
		Topic:      topic,
		Audience:   fallback(input.Audience, "middle school students"),
		Difficulty: normalizeDifficulty(input.Difficulty),
		Language:   fallback(input.Language, "English"),
	})
	if err != nil {
		return domaincontent.GenerateOutput{}, err
	}

	if strings.TrimSpace(output.Lesson.Id) == "" {
		output.Lesson.Id = defaultID("lesson", topic)
	}
	if strings.TrimSpace(output.Skill.Id) == "" {
		output.Skill.Id = defaultID("skill", topic)
	}
	if strings.TrimSpace(output.Lesson.Title) == "" || strings.TrimSpace(output.Skill.Title) == "" {
		return domaincontent.GenerateOutput{}, fmt.Errorf("generated content is missing required titles")
	}

	return output, nil
}

func fallback(value, defaultValue string) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return defaultValue
	}
	return trimmed
}

func normalizeDifficulty(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "beginner", "intermediate", "advanced":
		return strings.ToLower(strings.TrimSpace(value))
	default:
		return "beginner"
	}
}

func defaultID(prefix, seed string) string {
	normalized := slugify(seed)
	if normalized == "" {
		normalized = "content"
	}
	return fmt.Sprintf("%s-%s-%d", prefix, normalized, time.Now().Unix())
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

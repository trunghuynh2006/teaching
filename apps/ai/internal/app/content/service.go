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
)

var (
	ErrInvalidTopic         = errors.New("topic is required")
	ErrGeneratorUnavailable = errors.New("generator is not configured")
)

type Service struct {
	Generator domaincontent.Generator
	Cache     domaincontent.Cache
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

	normalizedInput := domaincontent.GenerateInput{
		Topic:      topic,
		Audience:   fallback(input.Audience, "middle school students"),
		Difficulty: normalizeDifficulty(input.Difficulty),
		Language:   fallback(input.Language, "English"),
	}
	cacheKey := promptCacheKey(normalizedInput)
	if s.Cache != nil {
		if cached, ok := s.Cache.Get(ctx, cacheKey); ok {
			return cached, nil
		}
	}

	output, err := s.Generator.GenerateLessonSkill(ctx, normalizedInput)
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
	if s.Cache != nil {
		s.Cache.Set(ctx, cacheKey, output)
	}

	return output, nil
}

func promptCacheKey(input domaincontent.GenerateInput) string {
	payload, err := json.Marshal(input)
	if err != nil {
		return input.Topic + "|" + input.Audience + "|" + input.Difficulty + "|" + input.Language
	}
	sum := sha256.Sum256(payload)
	return hex.EncodeToString(sum[:])
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

package content

import (
	"context"

	"ai/internal/sharedmodels"
)

type GenerateInput struct {
	Topic      string
	Audience   string
	Difficulty string
	Language   string
}

type GenerateOutput struct {
	Lesson sharedmodels.Lesson
	Skill  sharedmodels.Skill
}

type Generator interface {
	GenerateLessonSkill(ctx context.Context, input GenerateInput) (GenerateOutput, error)
}

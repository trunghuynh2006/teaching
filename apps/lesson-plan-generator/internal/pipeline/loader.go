package pipeline

import (
	"lesson-plan-generator/internal/domain"
	"lesson-plan-generator/internal/fixtures"
)

// step 1 – load lesson content.
func loadLesson(lessonID string) (domain.LessonContent, error) {
	return fixtures.Load(lessonID)
}

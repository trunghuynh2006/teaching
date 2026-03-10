package pipeline

import "lesson-plan-generator/internal/domain"

// step 2 – split narration into segments.
// Currently returns the pre-defined segments from the lesson.
// Future: accept raw narration text and auto-split on sentence boundaries.
func splitNarration(lesson domain.LessonContent) []domain.NarrationSegment {
	return lesson.Narration
}

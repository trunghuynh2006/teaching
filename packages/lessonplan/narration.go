package lessonplan

import "t2t.dev/lessonplan/domain"

// splitNarration returns the pre-defined narration segments from the lesson.
// Future: accept raw narration text and auto-split on sentence boundaries.
func splitNarration(lesson domain.LessonContent) []domain.NarrationSegment {
	return lesson.Narration
}

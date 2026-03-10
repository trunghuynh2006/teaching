// Package fixtures holds hard-coded lesson content.
// Replace loadLesson with a database or API call when lessons are stored externally.
package fixtures

import (
	"fmt"

	"lesson-plan-generator/internal/domain"
)

var lessons = map[string]domain.LessonContent{
	"email_clear_requests": {
		LessonID: "email_clear_requests",
		Title:    "Writing Clear Emails",
		Narration: []domain.NarrationSegment{
			{SegmentID: "s1", Text: "Many emails begin with unnecessary apologies."},
			{SegmentID: "s2", Text: "These phrases weaken the message."},
			{SegmentID: "s3", Text: "Instead of saying sorry to bother you, get straight to the point."},
			{SegmentID: "s4", Text: "Compare these two versions of the same request."},
			{SegmentID: "s5", Text: "The second version is shorter, clearer, and more confident."},
		},
		SceneScripts: []domain.SceneScript{
			{
				SceneID:             "scene_1",
				SceneType:           "title_scene",
				NarrationSegmentIDs: []string{},
				Data: map[string]any{
					"title":    "Writing Clear Emails",
					"duration": 3.0,
				},
			},
			{
				SceneID:             "scene_2",
				SceneType:           "edit_sentence",
				NarrationSegmentIDs: []string{"s1", "s2"},
				Data: map[string]any{
					"original_text":    "Sorry to bother you but I was wondering if we could move the meeting.",
					"replacement_text": "Can we move the meeting?",
					"highlight_phrase": "Sorry to bother you",
					"highlight_at":     1.2,
					"replace_at":       2.0,
				},
			},
			{
				SceneID:             "scene_3",
				SceneType:           "edit_sentence",
				NarrationSegmentIDs: []string{"s3", "s4", "s5"},
				Data: map[string]any{
					"original_text":    "I was just wondering if maybe you had a chance to look at my proposal.",
					"replacement_text": "Have you reviewed my proposal?",
					"highlight_phrase": "I was just wondering if maybe",
					"highlight_at":     1.5,
					"replace_at":       2.5,
				},
			},
		},
	},
}

func Load(lessonID string) (domain.LessonContent, error) {
	l, ok := lessons[lessonID]
	if !ok {
		return domain.LessonContent{}, fmt.Errorf("lesson %q not found", lessonID)
	}
	return l, nil
}

package scene

import "lesson-plan-generator/internal/domain"

type titleRule struct{}

func (titleRule) Build(script domain.SceneScript, _ []domain.AudioSegment, start, duration float64) map[string]any {
	return map[string]any{
		"scene_id":   script.SceneID,
		"scene_type": "title_scene",
		"start":      start,
		"duration":   duration,
		"title":      getString(script.Data, "title", ""),
	}
}

package scene

import "t2t.dev/lessonplan/domain"

type editSentenceRule struct{}

func (editSentenceRule) Build(script domain.SceneScript, _ []domain.AudioSegment, start, duration float64) map[string]any {
	d := script.Data
	highlightAt := round3(start + getFloat(d, "highlight_at", 1.2))
	replaceAt := round3(start + getFloat(d, "replace_at", 2.0))

	events := []map[string]any{
		{"time": start, "action": "show_original"},
		{"time": highlightAt, "action": "highlight_phrase", "text": getString(d, "highlight_phrase", "")},
		{"time": replaceAt, "action": "replace_sentence"},
	}

	return map[string]any{
		"scene_id":         script.SceneID,
		"scene_type":       "edit_sentence",
		"start":            start,
		"duration":         duration,
		"original_text":    getString(d, "original_text", ""),
		"replacement_text": getString(d, "replacement_text", ""),
		"events":           events,
	}
}

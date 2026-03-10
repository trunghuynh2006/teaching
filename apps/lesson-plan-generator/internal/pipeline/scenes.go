package pipeline

import "lesson-plan-generator/internal/domain"

type sceneEntry struct {
	script   domain.SceneScript
	duration float64
}

// step 5 – map scene scripts to (script, duration) pairs.
// Duration = sum of assigned audio segment durations, or data["duration"] for narration-free scenes.
func generateScenes(scripts []domain.SceneScript, audio []domain.AudioSegment) []sceneEntry {
	durMap := make(map[string]float64, len(audio))
	for _, s := range audio {
		durMap[s.SegmentID] = s.DurationSec
	}

	entries := make([]sceneEntry, 0, len(scripts))
	for _, script := range scripts {
		var duration float64
		if len(script.NarrationSegmentIDs) > 0 {
			for _, id := range script.NarrationSegmentIDs {
				duration += durMap[id]
			}
		} else {
			duration = getFloat(script.Data, "duration", 3.0)
		}
		entries = append(entries, sceneEntry{script: script, duration: duration})
	}
	return entries
}

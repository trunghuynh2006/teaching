package pipeline

import (
	"lesson-plan-generator/internal/domain"
	"lesson-plan-generator/internal/scene"
)

// step 6 – assign absolute timestamps.
//
// Audio segments: start times are relative to the audio file (0-based).
// Scenes:         start times are in the video timeline (sequential).
//
// The two timelines are independent: the video renderer starts the audio track
// when the first narration scene begins.
func computeTimeline(entries []sceneEntry, audio []domain.AudioSegment) ([]map[string]any, []domain.AudioSegment, error) {
	// --- Audio track: assign start times within the audio file ---
	segMap := make(map[string]domain.AudioSegment, len(audio))
	timed := make([]domain.AudioSegment, len(audio))
	var audioCursor float64
	for i, seg := range audio {
		seg.Start = round3(audioCursor)
		timed[i] = seg
		segMap[seg.SegmentID] = seg
		audioCursor += seg.DurationSec
	}

	// --- Video timeline: assign scene start times sequentially ---
	scenes := make([]map[string]any, 0, len(entries))
	var videoCursor float64
	for _, entry := range entries {
		rule, err := scene.Get(entry.script.SceneType)
		if err != nil {
			return nil, nil, err
		}

		sceneAudio := make([]domain.AudioSegment, 0, len(entry.script.NarrationSegmentIDs))
		for _, id := range entry.script.NarrationSegmentIDs {
			if s, ok := segMap[id]; ok {
				sceneAudio = append(sceneAudio, s)
			}
		}

		s := rule.Build(entry.script, sceneAudio, round3(videoCursor), round3(entry.duration))
		scenes = append(scenes, s)
		videoCursor += entry.duration
	}

	return scenes, timed, nil
}

package pipeline

import (
	"math"

	"lesson-plan-generator/internal/domain"
)

// step 7 – assemble the final VideoPlan JSON contract.
func assemble(lessonID string, segments []domain.AudioSegment, fullAudioFile string, scenes []map[string]any) domain.VideoPlan {
	var total float64
	for _, s := range segments {
		total += s.DurationSec
	}

	return domain.VideoPlan{
		LessonID: lessonID,
		AudioTrack: domain.AudioTrack{
			Segments:      segments,
			FullAudioFile: fullAudioFile,
			TotalDuration: math.Round(total*1000) / 1000,
		},
		Scenes: scenes,
	}
}

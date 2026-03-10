// Package lessonplan generates a VideoPlan (audio track + scene timeline) from a LessonContent.
package lessonplan

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"t2t.dev/lessonplan/domain"
)

// Re-export domain types so callers only need to import t2t.dev/lessonplan.
type (
	LessonContent     = domain.LessonContent
	NarrationSegment  = domain.NarrationSegment
	SceneScript       = domain.SceneScript
	AudioSegment      = domain.AudioSegment
	AudioTrack        = domain.AudioTrack
	VideoPlan         = domain.VideoPlan
)

// Generator holds configuration and runs the full plan pipeline.
type Generator struct {
	apiKey     string
	voice      string
	outputDir  string
	httpClient *http.Client
}

func New(apiKey, voice, outputDir string) *Generator {
	return &Generator{
		apiKey:     apiKey,
		voice:      voice,
		outputDir:  outputDir,
		httpClient: &http.Client{Timeout: 60 * time.Second},
	}
}

func (g *Generator) GeneratePlan(ctx context.Context, lesson domain.LessonContent) (domain.VideoPlan, error) {
	lessonID := lesson.LessonID

	// 1. Split narration
	segments := splitNarration(lesson)

	// 2 & 3. Generate TTS + measure durations
	audioSegments, err := g.generateTTS(ctx, segments, lessonID)
	if err != nil {
		return domain.VideoPlan{}, fmt.Errorf("tts: %w", err)
	}

	// Concatenate segments into full audio track
	fullAudioFile, err := concatenateAudio(audioSegments, lessonID, g.outputDir)
	if err != nil {
		return domain.VideoPlan{}, fmt.Errorf("concatenate: %w", err)
	}

	// 4. Map scene scripts → (script, duration)
	sceneData := generateScenes(lesson.SceneScripts, audioSegments)

	// 5. Compute video timeline + assign audio start times
	scenes, timedSegments, err := computeTimeline(sceneData, audioSegments)
	if err != nil {
		return domain.VideoPlan{}, fmt.Errorf("timeline: %w", err)
	}

	// 6. Assemble final VideoPlan
	return assemble(lessonID, timedSegments, fullAudioFile, scenes), nil
}

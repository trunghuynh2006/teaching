// Package pipeline orchestrates the lesson-plan generation steps.
package pipeline

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"lesson-plan-generator/internal/domain"
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

func (g *Generator) GeneratePlan(ctx context.Context, lessonID string) (domain.VideoPlan, error) {
	// 1. Load lesson
	lesson, err := loadLesson(lessonID)
	if err != nil {
		return domain.VideoPlan{}, fmt.Errorf("load: %w", err)
	}

	// 2. Split narration
	segments := splitNarration(lesson)

	// 3 & 4. Generate TTS + measure durations
	audioSegments, err := g.generateTTS(ctx, segments, lessonID)
	if err != nil {
		return domain.VideoPlan{}, fmt.Errorf("tts: %w", err)
	}

	// Concatenate segments into full audio track
	fullAudioFile, err := concatenateAudio(audioSegments, lessonID, g.outputDir)
	if err != nil {
		return domain.VideoPlan{}, fmt.Errorf("concatenate: %w", err)
	}

	// 5. Map scene scripts → (script, duration)
	sceneData := generateScenes(lesson.SceneScripts, audioSegments)

	// 6. Compute video timeline + assign audio start times
	scenes, timedSegments, err := computeTimeline(sceneData, audioSegments)
	if err != nil {
		return domain.VideoPlan{}, fmt.Errorf("timeline: %w", err)
	}

	// 7. Assemble final VideoPlan
	return assemble(lessonID, timedSegments, fullAudioFile, scenes), nil
}

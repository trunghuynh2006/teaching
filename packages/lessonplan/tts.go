package lessonplan

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"t2t.dev/lessonplan/audio"
	"t2t.dev/lessonplan/domain"
)

// generateTTS calls OpenAI TTS for each segment, saves MP3 files, and measures durations.
func (g *Generator) generateTTS(ctx context.Context, segments []domain.NarrationSegment, lessonID string) ([]domain.AudioSegment, error) {
	audioDir := filepath.Join(g.outputDir, lessonID, "audio")
	if err := os.MkdirAll(audioDir, 0o755); err != nil {
		return nil, fmt.Errorf("create audio dir: %w", err)
	}

	var result []domain.AudioSegment
	for _, seg := range segments {
		mp3Data, err := g.callTTS(ctx, seg.Text)
		if err != nil {
			return nil, fmt.Errorf("segment %s: %w", seg.SegmentID, err)
		}

		filePath := filepath.Join(audioDir, seg.SegmentID+".mp3")
		if err := os.WriteFile(filePath, mp3Data, 0o644); err != nil {
			return nil, fmt.Errorf("write %s: %w", filePath, err)
		}

		duration, err := audio.MeasureDuration(filePath)
		if err != nil {
			// fallback: estimate from file size at 128 kbps
			duration = round3(float64(len(mp3Data)) * 8.0 / 128_000.0)
		}

		result = append(result, domain.AudioSegment{
			SegmentID:   seg.SegmentID,
			Text:        seg.Text,
			AudioFile:   "audio/" + seg.SegmentID + ".mp3",
			DurationSec: duration,
			Start:       0, // assigned by timeline step
		})
	}
	return result, nil
}

func (g *Generator) callTTS(ctx context.Context, text string) ([]byte, error) {
	payload, _ := json.Marshal(map[string]string{
		"model":           "tts-1",
		"input":           text,
		"voice":           g.voice,
		"response_format": "mp3",
	})

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.openai.com/v1/audio/speech", bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+g.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("status %d: %s", resp.StatusCode, body)
	}
	return io.ReadAll(resp.Body)
}

// concatenateAudio joins individual MP3 segments into a single full.mp3.
func concatenateAudio(segments []domain.AudioSegment, lessonID, outputDir string) (string, error) {
	fullPath := filepath.Join(outputDir, lessonID, "audio", "full.mp3")
	out, err := os.Create(fullPath)
	if err != nil {
		return "", fmt.Errorf("create full.mp3: %w", err)
	}
	defer out.Close()

	for _, seg := range segments {
		part, err := os.ReadFile(filepath.Join(outputDir, lessonID, seg.AudioFile))
		if err != nil {
			return "", fmt.Errorf("read %s: %w", seg.AudioFile, err)
		}
		if _, err := out.Write(part); err != nil {
			return "", fmt.Errorf("write full.mp3: %w", err)
		}
	}
	return "audio/full.mp3", nil
}

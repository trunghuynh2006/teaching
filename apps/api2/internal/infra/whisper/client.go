package whisper

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"unicode"
)

// minAudioBytes is the minimum file size we'll send to Whisper.
// A WebM header alone is ~400 B; a 1-second Opus clip is ~8–16 KB.
// Files below this threshold contain no meaningful audio.
const minAudioBytes = 8192 // 8 KB

type Client struct {
	APIKey string
}

type transcribeResponse struct {
	Text  string `json:"text"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// Transcribe sends an audio file to the OpenAI Whisper API and returns the
// transcript. It returns ("", nil) when the file is too short or Whisper
// produces a hallucinated response (emoji-only, punctuation-only, etc.).
func (c *Client) Transcribe(ctx context.Context, audioPath string) (string, error) {
	info, err := os.Stat(audioPath)
	if err != nil {
		return "", fmt.Errorf("stat audio: %w", err)
	}
	if info.Size() < minAudioBytes {
		return "", nil // too short — no real speech
	}

	f, err := os.Open(audioPath)
	if err != nil {
		return "", fmt.Errorf("open audio: %w", err)
	}
	defer f.Close()

	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)

	fw, err := mw.CreateFormFile("file", filepath.Base(audioPath))
	if err != nil {
		return "", fmt.Errorf("create form file: %w", err)
	}
	if _, err := io.Copy(fw, f); err != nil {
		return "", fmt.Errorf("copy audio: %w", err)
	}
	if err := mw.WriteField("model", "whisper-1"); err != nil {
		return "", fmt.Errorf("write model field: %w", err)
	}
	mw.Close()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.openai.com/v1/audio/transcriptions", &buf)
	if err != nil {
		return "", fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	req.Header.Set("Content-Type", mw.FormDataContentType())

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("whisper request: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("whisper API %d: %s", resp.StatusCode, body)
	}

	var result transcribeResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("parse response: %w", err)
	}
	if result.Error != nil {
		return "", fmt.Errorf("whisper error: %s", result.Error.Message)
	}

	text := strings.TrimSpace(result.Text)
	if isHallucination(text) {
		return "", nil
	}
	return text, nil
}

// isHallucination returns true when Whisper's response contains no actual
// letters or digits — i.e. it's only emoji, punctuation, or whitespace.
// These are the characteristic hallucinations produced on silent audio.
func isHallucination(text string) bool {
	if text == "" {
		return false
	}
	for _, r := range text {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			return false
		}
	}
	return true
}

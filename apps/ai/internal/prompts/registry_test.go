package prompts_test

import (
	"strings"
	"testing"

	"ai/internal/prompts"
)

func TestNew_LoadsWithoutError(t *testing.T) {
	r, err := prompts.New()
	if err != nil {
		t.Fatalf("prompts.New() error: %v", err)
	}
	if r == nil {
		t.Fatal("registry is nil")
	}
}

func TestSystemPrompt_NotEmpty(t *testing.T) {
	r, _ := prompts.New()
	sp := r.SystemPrompt()
	if strings.TrimSpace(sp) == "" {
		t.Error("SystemPrompt() returned empty string")
	}
}

func TestRenderListTitles_ContainsSkillTitle(t *testing.T) {
	r, _ := prompts.New()
	out, err := r.RenderListTitles(prompts.ListTitlesData{
		SkillTitle: "Quadratic Equations",
		Count:      5,
		Audience:   "high school",
		Difficulty: "intermediate",
		Language:   "English",
	})
	if err != nil {
		t.Fatalf("RenderListTitles error: %v", err)
	}
	if !strings.Contains(out, "Quadratic Equations") {
		t.Errorf("rendered prompt does not contain skill title; got:\n%s", out)
	}
}

func TestRenderListTitles_ContainsCount(t *testing.T) {
	r, _ := prompts.New()
	out, err := r.RenderListTitles(prompts.ListTitlesData{
		SkillTitle: "Geometry",
		Count:      7,
	})
	if err != nil {
		t.Fatalf("RenderListTitles error: %v", err)
	}
	if !strings.Contains(out, "7") {
		t.Errorf("rendered prompt does not contain count 7; got:\n%s", out)
	}
}

func TestRenderGenerateLesson_ContainsLessonTitle(t *testing.T) {
	r, _ := prompts.New()
	out, err := r.RenderGenerateLesson(prompts.GenerateLessonData{
		LessonTitle: "Introduction to Fractions",
		SkillTitle:  "Fractions",
		Audience:    "middle school",
		Difficulty:  "beginner",
		Language:    "English",
	})
	if err != nil {
		t.Fatalf("RenderGenerateLesson error: %v", err)
	}
	if !strings.Contains(out, "Introduction to Fractions") {
		t.Errorf("rendered prompt does not contain lesson title; got:\n%s", out)
	}
}

func TestRenderGenerateLesson_ContainsSchema(t *testing.T) {
	r, _ := prompts.New()
	out, err := r.RenderGenerateLesson(prompts.GenerateLessonData{
		LessonTitle: "Variables",
		SkillTitle:  "Algebra",
	})
	if err != nil {
		t.Fatalf("RenderGenerateLesson error: %v", err)
	}
	// The schema JSON is embedded in the prompt — check for a recognisable field.
	if !strings.Contains(out, "title") {
		t.Errorf("rendered prompt does not contain schema content; got:\n%s", out)
	}
}

package content_test

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"

	"ai/internal/app/content"
	domaincontent "ai/internal/domain/content"
	"ai/internal/sharedmodels"
)

// --- mocks ---

type mockGenerator struct {
	titles    []string
	titlesErr error
	lesson    sharedmodels.Lesson
	lessonErr error
	calls     int
	mu        sync.Mutex
}

func (m *mockGenerator) ListLessonTitles(_ context.Context, _ domaincontent.ListTitlesInput) ([]string, error) {
	m.mu.Lock()
	m.calls++
	m.mu.Unlock()
	return m.titles, m.titlesErr
}

func (m *mockGenerator) GenerateLesson(_ context.Context, _ domaincontent.GenerateLessonInput) (sharedmodels.Lesson, error) {
	m.mu.Lock()
	m.calls++
	m.mu.Unlock()
	return m.lesson, m.lessonErr
}

type memCache struct {
	mu   sync.Mutex
	data map[string]json.RawMessage
}

func newMemCache() *memCache { return &memCache{data: map[string]json.RawMessage{}} }

func (c *memCache) Get(_ context.Context, key string) (json.RawMessage, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	v, ok := c.data[key]
	return v, ok
}

func (c *memCache) Set(_ context.Context, key string, value json.RawMessage) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data[key] = value
}

// --- ListLessonTitles tests ---

func TestListLessonTitles_Success(t *testing.T) {
	gen := &mockGenerator{titles: []string{"Intro to Algebra", "Variables and Expressions"}}
	svc := content.Service{Generator: gen}

	titles, err := svc.ListLessonTitles(context.Background(), content.ListTitlesInput{
		SkillTitle: "Algebra Basics",
		Count:      2,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(titles) != 2 {
		t.Errorf("len(titles) = %d, want 2", len(titles))
	}
}

func TestListLessonTitles_EmptySkillTitle(t *testing.T) {
	svc := content.Service{Generator: &mockGenerator{}}
	_, err := svc.ListLessonTitles(context.Background(), content.ListTitlesInput{SkillTitle: "   "})
	if !errors.Is(err, content.ErrInvalidSkillTitle) {
		t.Errorf("err = %v, want ErrInvalidSkillTitle", err)
	}
}

func TestListLessonTitles_NoGenerator(t *testing.T) {
	svc := content.Service{}
	_, err := svc.ListLessonTitles(context.Background(), content.ListTitlesInput{SkillTitle: "Math"})
	if !errors.Is(err, content.ErrGeneratorUnavailable) {
		t.Errorf("err = %v, want ErrGeneratorUnavailable", err)
	}
}

func TestListLessonTitles_DefaultCount(t *testing.T) {
	// Count <= 0 should default to 5 — generator is called (no error = success)
	gen := &mockGenerator{titles: []string{"a", "b", "c", "d", "e"}}
	svc := content.Service{Generator: gen}
	titles, err := svc.ListLessonTitles(context.Background(), content.ListTitlesInput{SkillTitle: "Math", Count: 0})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(titles) != 5 {
		t.Errorf("len(titles) = %d, want 5", len(titles))
	}
}

func TestListLessonTitles_CacheHit(t *testing.T) {
	gen := &mockGenerator{titles: []string{"Lesson A"}}
	cache := newMemCache()
	svc := content.Service{Generator: gen, Cache: cache}

	input := content.ListTitlesInput{SkillTitle: "Algebra", Count: 1}
	// first call populates cache
	if _, err := svc.ListLessonTitles(context.Background(), input); err != nil {
		t.Fatalf("first call: %v", err)
	}
	// second call should hit cache — generator call count stays at 1
	if _, err := svc.ListLessonTitles(context.Background(), input); err != nil {
		t.Fatalf("second call: %v", err)
	}
	if gen.calls != 1 {
		t.Errorf("generator called %d times, want 1 (cache should serve second call)", gen.calls)
	}
}

// --- GenerateLesson tests ---

func TestGenerateLesson_Success(t *testing.T) {
	lesson := sharedmodels.Lesson{Id: "intro-algebra-123", Title: "Intro to Algebra"}
	gen := &mockGenerator{lesson: lesson}
	svc := content.Service{Generator: gen}

	got, err := svc.GenerateLesson(context.Background(), content.GenerateLessonInput{
		LessonTitle: "Intro to Algebra",
		SkillTitle:  "Algebra",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Title != "Intro to Algebra" {
		t.Errorf("title = %q, want %q", got.Title, "Intro to Algebra")
	}
}

func TestGenerateLesson_EmptyLessonTitle(t *testing.T) {
	svc := content.Service{Generator: &mockGenerator{}}
	_, err := svc.GenerateLesson(context.Background(), content.GenerateLessonInput{LessonTitle: ""})
	if !errors.Is(err, content.ErrInvalidLessonTitle) {
		t.Errorf("err = %v, want ErrInvalidLessonTitle", err)
	}
}

func TestGenerateLesson_DefaultID(t *testing.T) {
	// Generator returns lesson without ID — service should fill it in
	lesson := sharedmodels.Lesson{Id: "", Title: "My Lesson"}
	gen := &mockGenerator{lesson: lesson}
	svc := content.Service{Generator: gen}

	got, err := svc.GenerateLesson(context.Background(), content.GenerateLessonInput{
		LessonTitle: "My Lesson",
		SkillTitle:  "Maths",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Id == "" {
		t.Error("expected a generated ID, got empty string")
	}
}

func TestGenerateLesson_MissingTitleError(t *testing.T) {
	// Generator returns lesson with no title — service should return error
	gen := &mockGenerator{lesson: sharedmodels.Lesson{Id: "x", Title: ""}}
	svc := content.Service{Generator: gen}

	_, err := svc.GenerateLesson(context.Background(), content.GenerateLessonInput{
		LessonTitle: "Something",
		SkillTitle:  "Math",
	})
	if err == nil {
		t.Error("expected error for missing title, got nil")
	}
}

func TestGenerateLesson_CacheHit(t *testing.T) {
	lesson := sharedmodels.Lesson{Id: "alg-1", Title: "Algebra 101"}
	gen := &mockGenerator{lesson: lesson}
	cache := newMemCache()
	svc := content.Service{Generator: gen, Cache: cache}

	input := content.GenerateLessonInput{LessonTitle: "Algebra 101", SkillTitle: "Algebra"}
	if _, err := svc.GenerateLesson(context.Background(), input); err != nil {
		t.Fatalf("first call: %v", err)
	}
	if _, err := svc.GenerateLesson(context.Background(), input); err != nil {
		t.Fatalf("second call: %v", err)
	}
	if gen.calls != 1 {
		t.Errorf("generator called %d times, want 1", gen.calls)
	}
}

func TestNormalizeDifficulty_Defaults(t *testing.T) {
	// An invalid difficulty should default to "beginner" via the service layer
	gen := &mockGenerator{lesson: sharedmodels.Lesson{Id: "x", Title: "T"}}
	svc := content.Service{Generator: gen}
	_, err := svc.GenerateLesson(context.Background(), content.GenerateLessonInput{
		LessonTitle: "T",
		Difficulty:  "unknown-level",
	})
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

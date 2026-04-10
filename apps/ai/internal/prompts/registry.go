// Package prompts loads and renders versioned prompt templates from embedded files.
// To change prompts, edit the files under internal/prompts/files/ and open a PR.
// Constraints are composable: each file in files/constraints/ can be included in
// multiple templates, ensuring consistent rules across all generation steps.
package prompts

import (
	"bytes"
	"embed"
	"fmt"
	"strings"
	"text/template"
)

//go:embed files
var filesFS embed.FS

// Registry holds compiled prompt templates and shared constraint blocks.
// Create one at startup via New and reuse it for all requests.
type Registry struct {
	systemPrompt              string
	contentQualityConstraints string
	lessonConstraints         string
	lessonSchema              string
	conceptsConstraints       string
	conceptsSchema            string
	listTitlesTmpl                   *template.Template
	generateLessonTmpl               *template.Template
	extractConceptsTmpl              *template.Template
	generateMCQuestionsTmpl          *template.Template
	seedFoundationConceptsTmpl       *template.Template
	discoverParentDomainsTmpl        *template.Template
	matchParentConceptsTmpl          *template.Template
	generateConceptMaterialsTmpl     *template.Template
	generateFlashCardsTmpl           *template.Template
}

// New loads all prompt files from the embedded filesystem and compiles templates.
// Returns an error if any file is missing or a template fails to parse.
func New() (*Registry, error) {
	read := func(path string) (string, error) {
		data, err := filesFS.ReadFile(path)
		if err != nil {
			return "", fmt.Errorf("prompt file %s: %w", path, err)
		}
		return strings.TrimSpace(string(data)), nil
	}
	parse := func(name, path string) (*template.Template, error) {
		raw, err := read(path)
		if err != nil {
			return nil, err
		}
		tmpl, err := template.New(name).Parse(raw)
		if err != nil {
			return nil, fmt.Errorf("parse template %s: %w", path, err)
		}
		return tmpl, nil
	}

	systemPrompt, err := read("files/system/curriculum-assistant.md")
	if err != nil {
		return nil, err
	}
	contentQuality, err := read("files/constraints/content-quality.md")
	if err != nil {
		return nil, err
	}
	lessonConstraints, err := read("files/constraints/lesson.md")
	if err != nil {
		return nil, err
	}
	lessonSchema, err := read("files/schemas/lesson.json")
	if err != nil {
		return nil, err
	}
	conceptsConstraints, err := read("files/constraints/concepts.md")
	if err != nil {
		return nil, err
	}
	conceptsSchema, err := read("files/schemas/concepts.json")
	if err != nil {
		return nil, err
	}
	listTitlesTmpl, err := parse("list-lesson-titles", "files/templates/list-lesson-titles.tmpl")
	if err != nil {
		return nil, err
	}
	generateLessonTmpl, err := parse("generate-lesson", "files/templates/generate-lesson.tmpl")
	if err != nil {
		return nil, err
	}
	extractConceptsTmpl, err := parse("extract-concepts", "files/templates/extract-concepts.tmpl")
	if err != nil {
		return nil, err
	}
	generateMCQuestionsTmpl, err := parse("generate-mc-questions", "files/templates/generate-mc-questions.tmpl")
	if err != nil {
		return nil, err
	}
	seedFoundationConceptsTmpl, err := parse("seed-foundation-concepts", "files/templates/seed-foundation-concepts.tmpl")
	if err != nil {
		return nil, err
	}
	discoverParentDomainsTmpl, err := parse("discover-parent-domains", "files/templates/discover-parent-domains.tmpl")
	if err != nil {
		return nil, err
	}
	matchParentConceptsTmpl, err := parse("match-parent-concepts", "files/templates/match-parent-concepts.tmpl")
	if err != nil {
		return nil, err
	}
	generateConceptMaterialsTmpl, err := parse("generate-concept-materials", "files/templates/generate-concept-materials.tmpl")
	if err != nil {
		return nil, err
	}
	generateFlashCardsTmpl, err := parse("generate-flash-cards", "files/templates/generate-flash-cards.tmpl")
	if err != nil {
		return nil, err
	}

	return &Registry{
		systemPrompt:              systemPrompt,
		contentQualityConstraints: contentQuality,
		lessonConstraints:         lessonConstraints,
		lessonSchema:              lessonSchema,
		conceptsConstraints:       conceptsConstraints,
		conceptsSchema:            conceptsSchema,
		listTitlesTmpl:                   listTitlesTmpl,
		generateLessonTmpl:               generateLessonTmpl,
		extractConceptsTmpl:              extractConceptsTmpl,
		generateMCQuestionsTmpl:          generateMCQuestionsTmpl,
		seedFoundationConceptsTmpl:       seedFoundationConceptsTmpl,
		discoverParentDomainsTmpl:        discoverParentDomainsTmpl,
		matchParentConceptsTmpl:          matchParentConceptsTmpl,
		generateConceptMaterialsTmpl:     generateConceptMaterialsTmpl,
		generateFlashCardsTmpl:           generateFlashCardsTmpl,
	}, nil
}

// GenerateFlashCardsData is the input data for the generate-flash-cards template.
type GenerateFlashCardsData struct {
	Concepts []string
	Domain   string
	Language string
}

// RenderGenerateFlashCards renders the user prompt for generating flashcards from a concept list.
func (r *Registry) RenderGenerateFlashCards(data GenerateFlashCardsData) (string, error) {
	var buf bytes.Buffer
	if err := r.generateFlashCardsTmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("render generate-flash-cards: %w", err)
	}
	return buf.String(), nil
}

// DiscoverParentDomainsData is the input data for the discover-parent-domains template.
type DiscoverParentDomainsData struct {
	Domain string
}

// RenderDiscoverParentDomains renders the user prompt for discovering parent domains.
func (r *Registry) RenderDiscoverParentDomains(data DiscoverParentDomainsData) (string, error) {
	var buf bytes.Buffer
	if err := r.discoverParentDomainsTmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("render discover-parent-domains: %w", err)
	}
	return buf.String(), nil
}

// MatchParentConceptsData is the input data for the match-parent-concepts template.
type MatchParentConceptsData struct {
	Domain         string
	ChildConcepts  []string
	ParentDomains  []string
	ParentConcepts []string
}

// RenderMatchParentConcepts renders the user prompt for matching parent concepts.
func (r *Registry) RenderMatchParentConcepts(data MatchParentConceptsData) (string, error) {
	var buf bytes.Buffer
	if err := r.matchParentConceptsTmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("render match-parent-concepts: %w", err)
	}
	return buf.String(), nil
}

// SeedFoundationConceptsData is the input data for the seed-foundation-concepts template.
type SeedFoundationConceptsData struct {
	Domain string
}

// RenderSeedFoundationConcepts renders the user prompt for seeding foundation concepts.
func (r *Registry) RenderSeedFoundationConcepts(data SeedFoundationConceptsData) (string, error) {
	var buf bytes.Buffer
	if err := r.seedFoundationConceptsTmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("render seed-foundation-concepts: %w", err)
	}
	return buf.String(), nil
}

// GenerateMCQuestionsData is the input data for the generate-mc-questions template.
type GenerateMCQuestionsData struct {
	SourceText string
	Language   string
}

// RenderGenerateMCQuestions renders the user prompt for generating multiple-choice questions.
func (r *Registry) RenderGenerateMCQuestions(data GenerateMCQuestionsData) (string, error) {
	var buf bytes.Buffer
	if err := r.generateMCQuestionsTmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("render generate-mc-questions: %w", err)
	}
	return buf.String(), nil
}

// SystemPrompt returns the base role/persona for the LLM system message.
func (r *Registry) SystemPrompt() string {
	return r.systemPrompt
}

// ListTitlesData is the input data for the list-lesson-titles template.
type ListTitlesData struct {
	SkillTitle string
	Count      int
	Audience   string
	Difficulty string
	Language   string
}

// RenderListTitles renders the user prompt for generating a list of lesson titles.
func (r *Registry) RenderListTitles(data ListTitlesData) (string, error) {
	type td struct {
		ListTitlesData
		ContentQualityConstraints string
	}
	var buf bytes.Buffer
	if err := r.listTitlesTmpl.Execute(&buf, td{
		ListTitlesData:            data,
		ContentQualityConstraints: r.contentQualityConstraints,
	}); err != nil {
		return "", fmt.Errorf("render list-lesson-titles: %w", err)
	}
	return buf.String(), nil
}

// GenerateLessonData is the input data for the generate-lesson template.
type GenerateLessonData struct {
	LessonTitle string
	SkillTitle  string
	Audience    string
	Difficulty  string
	Language    string
}

// ExtractConceptsData is the input data for the extract-concepts template.
type ExtractConceptsData struct {
	SourceText string
	Language   string
	Domain     string
}

// RenderExtractConcepts renders the user prompt for extracting concepts from source text.
func (r *Registry) RenderExtractConcepts(data ExtractConceptsData) (string, error) {
	type td struct {
		ExtractConceptsData
		ConceptsConstraints string
		ConceptsSchema      string
	}
	var buf bytes.Buffer
	if err := r.extractConceptsTmpl.Execute(&buf, td{
		ExtractConceptsData: data,
		ConceptsConstraints: r.conceptsConstraints,
		ConceptsSchema:      r.conceptsSchema,
	}); err != nil {
		return "", fmt.Errorf("render extract-concepts: %w", err)
	}
	return buf.String(), nil
}

// ConceptMaterialsData is the input data for the generate-concept-materials template.
type ConceptMaterialsData struct {
	ConceptName    string
	Description    string
	Example        string
	Analogy        string
	CommonMistakes string
	Level          string
	Domain         string
	Prerequisites  []string
	Language       string
}

// RenderGenerateConceptMaterials renders the user prompt for generating concept study materials.
func (r *Registry) RenderGenerateConceptMaterials(data ConceptMaterialsData) (string, error) {
	var buf bytes.Buffer
	if err := r.generateConceptMaterialsTmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("render generate-concept-materials: %w", err)
	}
	return buf.String(), nil
}

// RenderGenerateLesson renders the user prompt for generating full lesson content.
func (r *Registry) RenderGenerateLesson(data GenerateLessonData) (string, error) {
	type td struct {
		GenerateLessonData
		ContentQualityConstraints string
		LessonConstraints         string
		LessonSchema              string
	}
	var buf bytes.Buffer
	if err := r.generateLessonTmpl.Execute(&buf, td{
		GenerateLessonData:        data,
		ContentQualityConstraints: r.contentQualityConstraints,
		LessonConstraints:         r.lessonConstraints,
		LessonSchema:              r.lessonSchema,
	}); err != nil {
		return "", fmt.Errorf("render generate-lesson: %w", err)
	}
	return buf.String(), nil
}

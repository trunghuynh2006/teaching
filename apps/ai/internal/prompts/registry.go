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
	listTitlesTmpl            *template.Template
	generateLessonTmpl        *template.Template
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
	listTitlesTmpl, err := parse("list-lesson-titles", "files/templates/list-lesson-titles.tmpl")
	if err != nil {
		return nil, err
	}
	generateLessonTmpl, err := parse("generate-lesson", "files/templates/generate-lesson.tmpl")
	if err != nil {
		return nil, err
	}

	return &Registry{
		systemPrompt:              systemPrompt,
		contentQualityConstraints: contentQuality,
		lessonConstraints:         lessonConstraints,
		lessonSchema:              lessonSchema,
		listTitlesTmpl:            listTitlesTmpl,
		generateLessonTmpl:        generateLessonTmpl,
	}, nil
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

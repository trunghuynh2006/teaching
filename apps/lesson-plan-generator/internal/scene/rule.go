// Package scene defines the SceneRule interface and the rule registry.
//
// To add a new scene type:
//  1. Implement SceneRule in a new file in this package.
//  2. Register the instance in registry.go.
package scene

import "lesson-plan-generator/internal/domain"

// Rule knows how to turn a SceneScript + audio timing into a scene dict.
type Rule interface {
	Build(script domain.SceneScript, audio []domain.AudioSegment, start, duration float64) map[string]any
}

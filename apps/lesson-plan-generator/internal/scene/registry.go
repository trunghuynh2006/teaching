package scene

import "fmt"

var registry = map[string]Rule{
	"title_scene":   titleRule{},
	"edit_sentence": editSentenceRule{},
}

func Get(sceneType string) (Rule, error) {
	r, ok := registry[sceneType]
	if !ok {
		return nil, fmt.Errorf("unknown scene type %q; register it in internal/scene/registry.go", sceneType)
	}
	return r, nil
}

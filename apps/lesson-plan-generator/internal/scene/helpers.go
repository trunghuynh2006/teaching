package scene

import "math"

func round3(v float64) float64 {
	return math.Round(v*1000) / 1000
}

func getString(m map[string]any, key, fallback string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return fallback
}

func getFloat(m map[string]any, key string, fallback float64) float64 {
	if v, ok := m[key]; ok {
		switch f := v.(type) {
		case float64:
			return f
		case int:
			return float64(f)
		}
	}
	return fallback
}

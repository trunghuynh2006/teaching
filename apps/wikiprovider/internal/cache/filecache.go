// Package cache provides a file-based cache for SPARQL query results.
// Each entry is stored as a JSON file named by the SHA-256 hash of the cache key.
// Entries expire after TTL; stale files are deleted on read.
package cache

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

const DefaultTTL = 24 * time.Hour

type entry[T any] struct {
	Value     T         `json:"value"`
	ExpiresAt time.Time `json:"expires_at"`
}

// FileCache stores values as JSON files under Dir.
type FileCache[T any] struct {
	Dir string
	TTL time.Duration
}

// New creates a FileCache and ensures the directory exists.
func New[T any](dir string, ttl time.Duration) (*FileCache[T], error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("cache: create dir %s: %w", dir, err)
	}
	return &FileCache[T]{Dir: dir, TTL: ttl}, nil
}

func (c *FileCache[T]) path(key string) string {
	sum := sha256.Sum256([]byte(key))
	return filepath.Join(c.Dir, fmt.Sprintf("%x.json", sum))
}

// Get returns the cached value and true if found and not expired.
func (c *FileCache[T]) Get(key string) (T, bool) {
	var zero T
	data, err := os.ReadFile(c.path(key))
	if err != nil {
		return zero, false
	}
	var e entry[T]
	if err := json.Unmarshal(data, &e); err != nil {
		return zero, false
	}
	if time.Now().After(e.ExpiresAt) {
		_ = os.Remove(c.path(key))
		return zero, false
	}
	return e.Value, true
}

// Set writes the value to the cache with the configured TTL.
func (c *FileCache[T]) Set(key string, value T) {
	e := entry[T]{Value: value, ExpiresAt: time.Now().Add(c.TTL)}
	data, err := json.Marshal(e)
	if err != nil {
		return
	}
	_ = os.WriteFile(c.path(key), data, 0o644)
}

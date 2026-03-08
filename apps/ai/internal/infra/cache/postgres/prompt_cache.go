package postgres

import (
	"context"
	"encoding/json"
	"time"

	"ai/internal/store"
)

type PromptCache struct {
	queries    *store.Queries
	ttlSeconds int32
	maxEntries int32
}

func NewPromptCache(queries *store.Queries, ttl time.Duration, maxEntries int) *PromptCache {
	ttlSeconds := int32(ttl.Seconds())
	if ttlSeconds <= 0 {
		ttlSeconds = 900
	}
	if maxEntries < 0 {
		maxEntries = 0
	}
	return &PromptCache{
		queries:    queries,
		ttlSeconds: ttlSeconds,
		maxEntries: int32(maxEntries),
	}
}

func (c *PromptCache) Get(ctx context.Context, key string) (json.RawMessage, bool) {
	if c == nil || c.queries == nil || c.maxEntries == 0 {
		return nil, false
	}
	entry, err := c.queries.GetPromptCacheEntry(ctx, key)
	if err != nil {
		return nil, false
	}
	return entry.Response, true
}

func (c *PromptCache) Set(ctx context.Context, key string, value json.RawMessage) {
	if c == nil || c.queries == nil || c.maxEntries == 0 {
		return
	}
	_ = c.queries.UpsertPromptCacheEntry(ctx, store.UpsertPromptCacheEntryParams{
		CacheKey:   key,
		Response:   value,
		TtlSeconds: c.ttlSeconds,
	})
	_ = c.queries.DeleteExpiredPromptCacheEntries(ctx)
	_ = c.queries.PrunePromptCacheEntries(ctx, c.maxEntries)
}

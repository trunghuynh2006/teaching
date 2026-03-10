// Package llm provides a provider-agnostic interface for LLM chat completions.
//
// Usage:
//
//	client := &openai.Client{APIKey: "...", Model: "gpt-4o-mini"}
//	resp, err := client.Complete(ctx, llm.Request{
//	    SystemPrompt: "You are a helpful teacher.",
//	    UserPrompt:   "List 5 lesson titles about email writing.",
//	    JSONMode:     true,
//	})
package llm

import "context"

// Client is the provider-agnostic interface for LLM chat completions.
// Implement this interface to add a new provider (e.g. Anthropic, Gemini).
type Client interface {
	Complete(ctx context.Context, req Request) (string, error)
}

// Request describes a single chat completion turn.
type Request struct {
	SystemPrompt string
	UserPrompt   string
	// Model overrides the client-level default when non-empty.
	Model       string
	Temperature float64
	// JSONMode instructs the model to respond with a valid JSON object.
	JSONMode bool
}

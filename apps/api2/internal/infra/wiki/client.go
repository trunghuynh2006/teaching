// Package wiki provides an HTTP client for calling the internal wikiprovider service.
package wiki

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Client calls the internal wikiprovider service.
type Client struct {
	BaseURL    string
	HTTPClient *http.Client
}

// Concept is one result from the wikiprovider.
type Concept struct {
	QID         string `json:"qid"`
	Label       string `json:"label"`
	Description string `json:"description,omitempty"`
	ParentQID   string `json:"parent_qid,omitempty"`
	ParentLabel string `json:"parent_label,omitempty"`
}

func (c *Client) httpClient() *http.Client {
	if c.HTTPClient != nil {
		return c.HTTPClient
	}
	return &http.Client{Timeout: 20 * time.Second}
}

func (c *Client) get(ctx context.Context, path string, params url.Values) ([]Concept, error) {
	u := strings.TrimSuffix(c.BaseURL, "/") + path
	if len(params) > 0 {
		u += "?" + params.Encode()
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.httpClient().Do(req)
	if err != nil {
		return nil, fmt.Errorf("wikiprovider unavailable: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= http.StatusBadRequest {
		var e struct{ Detail string `json:"detail"` }
		if jsonErr := json.Unmarshal(body, &e); jsonErr == nil && e.Detail != "" {
			return nil, fmt.Errorf("wikiprovider: %s", e.Detail)
		}
		return nil, fmt.Errorf("wikiprovider returned %d", resp.StatusCode)
	}
	var out []Concept
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, fmt.Errorf("wikiprovider: parse response: %w", err)
	}
	return out, nil
}

// SearchConcepts queries the wikiprovider for concepts matching a label.
func (c *Client) SearchConcepts(ctx context.Context, q string, limit int) ([]Concept, error) {
	p := url.Values{"q": {q}}
	if limit > 0 {
		p.Set("limit", fmt.Sprint(limit))
	}
	return c.get(ctx, "/concepts/search", p)
}

// GetConceptsByDomain returns foundational concepts for a domain.
func (c *Client) GetConceptsByDomain(ctx context.Context, domain string, limit int) ([]Concept, error) {
	p := url.Values{"domain": {domain}}
	if limit > 0 {
		p.Set("limit", fmt.Sprint(limit))
	}
	return c.get(ctx, "/concepts/by-domain", p)
}

// GetConceptByQID returns a single concept with its parent links.
func (c *Client) GetConceptByQID(ctx context.Context, qid string) ([]Concept, error) {
	return c.get(ctx, "/concepts/"+qid, nil)
}

package handler

import (
	"net/http"

	"golang.org/x/time/rate"
)

// inboundLimiter throttles requests arriving at this service.
// api2 is the only caller; 20 req/s with burst 40 is generous but prevents runaway loops.
var inboundLimiter = rate.NewLimiter(20, 40)

// outboundLimiter throttles calls leaving this service to Wikidata's SPARQL endpoint.
// Wikidata recommends ≤1 req/s for automated clients; 2 req/s with burst 5 is safe.
var outboundLimiter = rate.NewLimiter(2, 5)

// InboundRateLimit is HTTP middleware that enforces the inbound rate limit.
func InboundRateLimit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !inboundLimiter.Allow() {
			writeJSON(w, http.StatusTooManyRequests, errorResponse{Detail: "rate limit exceeded — try again shortly"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

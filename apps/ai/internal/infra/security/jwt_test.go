package security_test

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"ai/internal/infra/security"
)

const testSecret = "supersecret"
const testAlg = "HS256"

func makeToken(secret, subject, role string, expiry time.Duration) string {
	claims := jwt.MapClaims{
		"sub":  subject,
		"role": role,
		"exp":  time.Now().Add(expiry).Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, _ := tok.SignedString([]byte(secret))
	return signed
}

func TestJWT_Parse_ValidToken(t *testing.T) {
	j := security.JWT{Secret: testSecret, Algorithm: testAlg}
	token := makeToken(testSecret, "alice", "teacher", time.Hour)

	claims, err := j.Parse(token)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if claims.Subject != "alice" {
		t.Errorf("subject = %q, want alice", claims.Subject)
	}
	if claims.Role != "teacher" {
		t.Errorf("role = %q, want teacher", claims.Role)
	}
}

func TestJWT_Parse_WrongSecret(t *testing.T) {
	j := security.JWT{Secret: testSecret, Algorithm: testAlg}
	token := makeToken("wrong-secret", "alice", "teacher", time.Hour)

	_, err := j.Parse(token)
	if err == nil {
		t.Error("expected error for wrong secret, got nil")
	}
}

func TestJWT_Parse_ExpiredToken(t *testing.T) {
	j := security.JWT{Secret: testSecret, Algorithm: testAlg}
	token := makeToken(testSecret, "alice", "teacher", -time.Minute)

	_, err := j.Parse(token)
	if err == nil {
		t.Error("expected error for expired token, got nil")
	}
}

func TestJWT_Parse_MalformedToken(t *testing.T) {
	j := security.JWT{Secret: testSecret, Algorithm: testAlg}
	_, err := j.Parse("not.a.token")
	if err == nil {
		t.Error("expected error for malformed token, got nil")
	}
}

func TestJWT_Parse_MissingSub(t *testing.T) {
	j := security.JWT{Secret: testSecret, Algorithm: testAlg}
	// token without "sub" claim
	claims := jwt.MapClaims{
		"role": "admin",
		"exp":  time.Now().Add(time.Hour).Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, _ := tok.SignedString([]byte(testSecret))

	_, err := j.Parse(signed)
	if err == nil {
		t.Error("expected error for missing sub, got nil")
	}
}

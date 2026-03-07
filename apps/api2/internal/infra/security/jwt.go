package security

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type JWT struct {
	Secret        string
	Algorithm     string
	ExpireMinutes int
}

func (j JWT) CreateAccessToken(subject, role string) (string, error) {
	expiresAt := time.Now().UTC().Add(time.Duration(j.ExpireMinutes) * time.Minute)

	method := jwt.GetSigningMethod(j.Algorithm)
	if method == nil {
		return "", fmt.Errorf("unsupported jwt algorithm: %s", j.Algorithm)
	}

	token := jwt.NewWithClaims(method, jwt.MapClaims{
		"sub":  subject,
		"role": role,
		"exp":  expiresAt.Unix(),
	})

	return token.SignedString([]byte(j.Secret))
}

func (j JWT) ParseSubject(tokenString string) (string, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (any, error) {
		if token.Method.Alg() != j.Algorithm {
			return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
		}
		return []byte(j.Secret), nil
	})
	if err != nil || !token.Valid {
		return "", errors.New("invalid token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("invalid token payload")
	}

	sub, ok := claims["sub"].(string)
	if !ok || sub == "" {
		return "", errors.New("invalid token payload")
	}

	return sub, nil
}

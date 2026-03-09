package security

import (
	"errors"
	"fmt"

	"github.com/golang-jwt/jwt/v5"
)

// Claims holds the validated fields extracted from a JWT.
type Claims struct {
	Subject string
	Role    string
}

// JWT verifies tokens signed with the same secret used by api2.
type JWT struct {
	Secret    string
	Algorithm string
}

// Parse validates tokenString and returns the embedded claims.
func (j JWT) Parse(tokenString string) (Claims, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (any, error) {
		if token.Method.Alg() != j.Algorithm {
			return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
		}
		return []byte(j.Secret), nil
	})
	if err != nil || !token.Valid {
		return Claims{}, errors.New("invalid token")
	}

	mc, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return Claims{}, errors.New("invalid token payload")
	}

	sub, _ := mc["sub"].(string)
	role, _ := mc["role"].(string)
	if sub == "" {
		return Claims{}, errors.New("invalid token payload")
	}

	return Claims{Subject: sub, Role: role}, nil
}

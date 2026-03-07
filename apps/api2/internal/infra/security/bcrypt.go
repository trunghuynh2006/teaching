package security

import "golang.org/x/crypto/bcrypt"

type Bcrypt struct{}

func (b Bcrypt) Verify(hashed, plain string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashed), []byte(plain))
}
